#include <Cocoa/Cocoa.h>
#include "Aux.h"

namespace VFSNetDropbox {

const char *GetString( const rapidjson::Value &_doc, const char *_key )
{
    auto i = _doc.FindMember(_key);
    if( i == _doc.MemberEnd() )
        return nullptr;
    if( !i->value.IsString() )
        return nullptr;
    return i->value.GetString();
}

optional<long> GetLong( const rapidjson::Value &_doc, const char *_key )
{
    auto i = _doc.FindMember(_key);
    if( i == _doc.MemberEnd() )
        return nullopt;
    if( !i->value.IsInt() )
        return nullopt;
    return i->value.GetInt64();
}

NSData *SendSynchonousRequest(NSURLSession *_session,
                              NSURLRequest *_request,
                              __autoreleasing NSURLResponse **_response_ptr,
                              __autoreleasing NSError **_error_ptr)
{
    dispatch_semaphore_t    sem;
    __block NSData *        result;
    
    result = nil;
    
    sem = dispatch_semaphore_create(0);
    
    NSURLSessionDataTask *task =
    [_session dataTaskWithRequest:_request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if( _error_ptr != nullptr ) {
                        *_error_ptr = error;
                    }
                    if( _response_ptr != nullptr ) {
                        *_response_ptr = response;
                    }
                    if( error == nil ) {
                        result = data;
                    }
                    dispatch_semaphore_signal(sem);
                }];
    
    [task resume];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    return result;
}

//- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
//                                     didReceiveData:(NSData *)data;


Metadata ParseMetadata( const rapidjson::Value &_value )
{
    static const auto file_type = "file"s, folder_type = "folder"s;
    static const auto date_formatter = []{
        NSDateFormatter * df = [[NSDateFormatter alloc] init];
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
                    m.chg_time = date.timeIntervalSince1970;
    }
    else if( folder_type == type ) {
        m.is_directory = true;
    }

    return m;
}

vector<Metadata> ExtractMetadataEntries( const rapidjson::Value &_value )
{
    if( !_value.IsObject() )
        return {};

    vector<Metadata> result;

    auto entries = _value.FindMember("entries");
    if( entries != _value.MemberEnd() )
        for( int i = 0, e = entries->value.Size(); i != e; ++i ) {
            auto &entry = entries->value[i];
            auto metadata = ParseMetadata(entry);
            if( !metadata.name.empty() )
                result.emplace_back( move(metadata) );
        }
    return result;
}


string EscapeString(const string &_original)
{
    string after;
    after.reserve(_original.length() + 4);
    for( auto c: _original ) {
        switch( c ) {
            case '"':
            case '\\':
                after += '\\';
            default:
                after += c;
        }
    }
    return after;
}

string EscapeStringForJSONInHTTPHeader(const string &_original)
{
    NSString *str = [NSString stringWithUTF8String:_original.c_str()];
    if( !str )
        return {};
    
    string after;
    after.reserve(str.length + 4);
    char hex[16];
    for( int i = 0, e = (int)str.length; i != e; ++i ) {
        auto c = [str characterAtIndex:i];
        if( c >= 127 ) {
            sprintf(hex, "\\u%04X", c);
            after += hex;
        }
        else {
            if( c == '"' || c == '\\' )
                after += '\\';
            after += c;
        }
    }
    return after;
}

bool IsNormalJSONResponse( NSURLResponse *_response )
{
    if( auto http_resp = objc_cast<NSHTTPURLResponse>(_response) ) {
        if( http_resp.statusCode != 200 )
            return false;
        
        if( id ct = http_resp.allHeaderFields[@"Content-Type"] )
            if( auto t = objc_cast<NSString>(ct) )
                return [t isEqualToString:@"application/json"];
    }
    return false;
}

//vector<Metadata> ListFolder(const string& _token,
//                            const string &_folder,
//                            const function<bool()> _cancellation )
//{
//                                
//                                
//}

void WarnAboutUsingInMainThread()
{
    auto msg = "usage of the net_dropbox vfs in the main thread may reduce responsiveness "
               "and should be avoided!";
    if( dispatch_is_main_queue() )
        cout << msg << endl;
}

AccountInfo ParseAccountInfo( const rapidjson::Value &_value )
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

}


