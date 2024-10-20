// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>
#include <VFS/VFSError.h>
#include "Aux.h"
#include <VFS/Log.h>
#include <Utility/ObjCpp.h>
#include <vector>
#include <fmt/format.h>

namespace nc::vfs::dropbox {

NSURL *const api::GetCurrentAccount = [NSURL URLWithString:@"https://api.dropboxapi.com/2/users/get_current_account"];
NSURL *const api::GetSpaceUsage = [NSURL URLWithString:@"https://api.dropboxapi.com/2/users/get_space_usage"];
NSURL *const api::GetMetadata = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/get_metadata"];
NSURL *const api::ListFolder = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/list_folder"];
NSURL *const api::ListFolderContinue = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/list_folder/continue"];
NSURL *const api::Delete = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/delete"];
NSURL *const api::CreateFolder = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/create_folder"];
NSURL *const api::Download = [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/download"];
NSURL *const api::Upload = [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload"];
NSURL *const api::UploadSessionStart =
    [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload_session/start"];
NSURL *const api::UploadSessionAppend =
    [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload_session/append_v2"];
NSURL *const api::UploadSessionFinish =
    [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload_session/finish"];
NSURL *const api::Move = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/move"];
NSURL *const api::OAuth2Token = [NSURL URLWithString:@"https://api.dropbox.com/oauth2/token"];
NSURL *const api::OAuth2Authorize = [NSURL URLWithString:@"https://www.dropbox.com/oauth2/authorize"];

const char *GetString(const rapidjson::Value &_doc, const char *_key)
{
    auto i = _doc.FindMember(_key);
    if( i == _doc.MemberEnd() )
        return nullptr;
    if( !i->value.IsString() )
        return nullptr;
    return i->value.GetString();
}

std::optional<long> GetLong(const rapidjson::Value &_doc, const char *_key)
{
    auto i = _doc.FindMember(_key);
    if( i == _doc.MemberEnd() )
        return std::nullopt;
    if( !i->value.IsInt() )
        return std::nullopt;
    return i->value.GetInt64();
}

static int ExtractVFSErrorFromObject(const rapidjson::Value &_object)
{
    using namespace std::literals;

    auto tag = GetString(_object, ".tag");
    if( !tag )
        return VFSError::GenericError;

    auto error_node = _object.FindMember(tag);
    if( error_node == _object.MemberEnd() || !error_node->value.IsObject() )
        return VFSError::GenericError;

    auto error_tag = GetString(error_node->value, ".tag");
    if( !error_tag )
        return VFSError::GenericError;

    if( "not_found"s == error_tag )
        return VFSError::FromErrno(ENOENT);
    if( "not_file"s == error_tag )
        return VFSError::FromErrno(EISDIR);
    if( "not_folder"s == error_tag )
        return VFSError::FromErrno(ENOTDIR);
    if( "restricted_content"s == error_tag )
        return VFSError::FromErrno(EACCES);
    if( "invalid_path_root"s == error_tag )
        return VFSError::FromErrno(ENOENT);
    if( "malformed_path"s == error_tag )
        return VFSError::FromErrno(EINVAL);
    if( "conflict"s == error_tag )
        return VFSError::FromErrno(EBUSY);
    if( "no_write_permission"s == error_tag )
        return VFSError::FromErrno(EPERM);
    if( "insufficient_space"s == error_tag )
        return VFSError::FromErrno(ENOSPC);
    if( "disallowed_name"s == error_tag )
        return VFSError::FromErrno(EINVAL);
    if( "team_folder"s == error_tag )
        return VFSError::FromErrno(EACCES);

    return VFSError::GenericError;
}

int ExtractVFSErrorFromJSON(NSData *_response_data)
{
    auto optional_json = ParseJSON(_response_data);
    if( !optional_json )
        return VFSError::GenericError;
    auto &json = *optional_json;

    if( !json.IsObject() )
        return VFSError::GenericError;

    auto error_node = json.FindMember("error");
    if( error_node == json.MemberEnd() )
        return VFSError::GenericError;

    if( !error_node->value.IsObject() )
        return VFSError::GenericError;

    return ExtractVFSErrorFromObject(error_node->value);
}

int VFSErrorFromErrorAndReponseAndData(NSError *_error, NSURLResponse *_response, NSData *_data)
{
    int vfs_error = VFSError::FromErrno(EIO);
    if( _error )
        vfs_error = VFSError::FromNSError(_error);
    else if( auto http_response = objc_cast<NSHTTPURLResponse>(_response) ) {
        const auto sc = http_response.statusCode;
        if( sc == 400 )
            vfs_error = VFSError::FromErrno(EINVAL);
        else if( sc == 401 )
            vfs_error = VFSError::FromErrno(EAUTH);
        else if( sc == 409 && _data )
            vfs_error = ExtractVFSErrorFromJSON(_data);
        else if( sc == 429 )
            vfs_error = VFSError::FromErrno(EBUSY);
        else if( sc >= 500 && sc < 600 )
            vfs_error = VFSError::FromErrno(EIO);
    }

    return vfs_error;
}

static std::pair<int, NSData *> SendInfiniteSynchronousRequest(NSURLSession *_session, NSURLRequest *_request)
{
    assert(_session != nil);
    assert(_request != nil);
    Log::Debug("Sending infinite sync request at {}", _request.URL.absoluteString.UTF8String);
    const dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSURLResponse *response = nil;
    __block NSError *error = nil;

    NSURLSessionDataTask *const task =
        [_session dataTaskWithRequest:_request
                    completionHandler:^(NSData *_data, NSURLResponse *_response, NSError *_error) {
                      error = _error;
                      response = _response;
                      if( _error == nil )
                          data = _data;
                      dispatch_semaphore_signal(sem);
                    }];

    [task resume];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    if( error == nil && data != nil && response != nil )
        if( auto http_resp = objc_cast<NSHTTPURLResponse>(response) )
            if( http_resp.statusCode == 200 )
                return {VFSError::Ok, data};

    return {VFSErrorFromErrorAndReponseAndData(error, response, data), nil};
}

std::pair<int, NSData *>
SendSynchronousRequest(NSURLSession *_session, NSURLRequest *_request, const VFSCancelChecker &_cancel_checker)
{
    assert(_session != nil);
    assert(_request != nil);
    if( !_cancel_checker )
        return SendInfiniteSynchronousRequest(_session, _request);

    Log::Debug("Sending finite sync request at {}", _request.URL.absoluteString.UTF8String);
    const auto timeout = 100 * NSEC_PER_MSEC; // wake up every 100ms
    const dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSURLResponse *response = nil;
    __block NSError *error = nil;

    auto completion_handler = ^(NSData *_data, NSURLResponse *_response, NSError *_error) {
      error = _error;
      response = _response;
      if( _error == nil )
          data = _data;
      dispatch_semaphore_signal(sem);
    };

    auto task = [_session dataTaskWithRequest:_request completionHandler:completion_handler];
    [task resume];

    while( dispatch_semaphore_wait(sem, timeout) )
        if( _cancel_checker() ) {
            [task cancel];
            return {VFSError::Cancelled, nil};
        }

    if( error == nil && data != nil && response != nil )
        if( auto http_resp = objc_cast<NSHTTPURLResponse>(response) )
            if( http_resp.statusCode == 200 )
                return {VFSError::Ok, data};

    return {VFSErrorFromErrorAndReponseAndData(error, response, data), nil};
}

Metadata ParseMetadata(const rapidjson::Value &_value)
{
    using namespace std::literals;
    [[clang::no_destroy]] static const auto file_type = "file"s;
    [[clang::no_destroy]] static const auto folder_type = "folder"s;
    [[clang::no_destroy]] static const auto date_formatter = [] {
        NSDateFormatter *const df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        return df;
    }();

    if( !_value.IsObject() )
        return {};

    const auto type = GetString(_value, ".tag");
    if( !type )
        return {};

    Metadata m;

    if( auto name = GetString(_value, "name") )
        m.name = name;

    if( file_type == type ) {
        m.is_directory = false;

        if( auto size = GetLong(_value, "size") )
            m.size = *size;

        if( auto mod_date = GetString(_value, "server_modified") )
            if( auto str = [NSString stringWithUTF8String:mod_date] )
                if( auto date = [date_formatter dateFromString:str] )
                    m.chg_time = int64_t(date.timeIntervalSince1970);
    }
    else if( folder_type == type ) {
        m.is_directory = true;
    }

    return m;
}

std::vector<Metadata> ExtractMetadataEntries(const rapidjson::Value &_value)
{
    if( !_value.IsObject() )
        return {};

    std::vector<Metadata> result;

    auto entries = _value.FindMember("entries");
    if( entries != _value.MemberEnd() )
        for( int i = 0, e = entries->value.Size(); i != e; ++i ) {
            auto &entry = entries->value[i];
            auto metadata = ParseMetadata(entry);
            if( !metadata.name.empty() )
                result.emplace_back(std::move(metadata));
        }
    return result;
}

std::string EscapeString(std::string_view _original)
{
    std::string after;
    after.reserve(_original.length() + 4);
    for( auto c : _original ) {
        switch( c ) {
            case '"':
                [[fallthrough]];
            case '\\':
                after += '\\';
                [[fallthrough]];
            default:
                after += c;
        }
    }
    return after;
}

std::string EscapeStringForJSONInHTTPHeader(const std::string &_original)
{
    NSString *const str = [NSString stringWithUTF8String:_original.c_str()];
    if( !str )
        return {};

    std::string after;
    after.reserve(str.length + 4);
    for( int i = 0, e = static_cast<int>(str.length); i != e; ++i ) {
        auto c = [str characterAtIndex:i];
        if( c >= 127 ) {
            fmt::format_to(std::back_inserter(after), "\\u{:04X}", c);
        }
        else {
            if( c == '"' || c == '\\' )
                after += '\\';
            after += static_cast<char>(c);
        }
    }
    return after;
}

bool IsNormalJSONResponse(NSURLResponse *_response)
{
    if( auto http_resp = objc_cast<NSHTTPURLResponse>(_response) ) {
        if( http_resp.statusCode != 200 )
            return false;

        if( const id ct = http_resp.allHeaderFields[@"Content-Type"] )
            if( auto t = objc_cast<NSString>(ct) )
                return [t isEqualToString:@"application/json"];
    }
    return false;
}

AccountInfo ParseAccountInfo(const rapidjson::Value &_value)
{
    if( !_value.IsObject() )
        return {};

    const auto account_id = GetString(_value, "account_id");
    if( !account_id )
        return {};

    const auto email = GetString(_value, "email");
    if( !email )
        return {};

    AccountInfo ai;
    ai.accountid = account_id;
    ai.email = email;

    return ai;
}

std::optional<std::string> ParseRefreshTokenReponse(const rapidjson::Value &_value)
{
    if( !_value.IsObject() )
        return {};

    const auto token = GetString(_value, "token_type");
    if( token == nullptr || std::string_view("bearer") != token )
        return {};

    const auto access_token = GetString(_value, "access_token");
    if( access_token == nullptr )
        return {};

    return std::string(access_token);
}

std::optional<rapidjson::Document> ParseJSON(NSData *_data)
{
    if( !_data )
        return std::nullopt;

    using namespace rapidjson;
    Document json;
    const ParseResult ok = json.Parse<kParseNoFlags>(static_cast<const char *>(_data.bytes), _data.length);
    if( !ok )
        return std::nullopt;
    return std::move(json);
}

void InsertHTTPBodyPathspec(NSMutableURLRequest *_request, std::string_view _path)
{
    [_request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    const std::string path_spec = R"({ "path": ")" + EscapeString(_path) + "\" }";
    [_request setHTTPBody:[NSData dataWithBytes:data(path_spec) length:size(path_spec)]];
}

void InsertHTTPBodyCursor(NSMutableURLRequest *_request, const std::string &_cursor)
{
    [_request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    const std::string cursor_spec = R"({ "cursor": ")" + EscapeString(_cursor) + "\" }";
    [_request setHTTPBody:[NSData dataWithBytes:data(cursor_spec) length:size(cursor_spec)]];
}

void InsertHTTPHeaderPathspec(NSMutableURLRequest *_request, const std::string &_path)
{
    const std::string path_spec = R"({ "path": ")" + EscapeStringForJSONInHTTPHeader(_path) + "\" }";
    [_request setValue:[NSString stringWithUTF8String:path_spec.c_str()] forHTTPHeaderField:@"Dropbox-API-Arg"];
}

} // namespace nc::vfs::dropbox
