
#include "Aux.h"
#include "VFSNetDropboxHost.h"

using namespace VFSNetDropbox;

const char *VFSNetDropboxHost::Tag = "net_dropbox";

static const auto g_GetSpaceUsage = [NSURL URLWithString:@"https://api.dropboxapi.com/2/users/get_space_usage"];
static const auto g_GetMetadata = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/get_metadata"];

static string EscapeString(const char *_original)
{
    static const auto acs = NSCharacterSet.URLQueryAllowedCharacterSet;
    return [[NSString stringWithUTF8String:_original]
        stringByAddingPercentEncodingWithAllowedCharacters:acs].UTF8String;
}

static string EscapeString(const string &_original)
{
    return EscapeString( _original.c_str() );
}

static bool IsNormalJSONResponse( NSURLResponse *_response )
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

static const char *GetString( const rapidjson::Document &_doc, const char *_key )
{
    auto i = _doc.FindMember(_key);
    if( i == _doc.MemberEnd() )
        return nullptr;
    if( !i->value.IsString() )
        return nullptr;
    return i->value.GetString();
}

static optional<long> GetLong( const rapidjson::Document &_doc, const char *_key )
{
    auto i = _doc.FindMember(_key);
    if( i == _doc.MemberEnd() )
        return nullopt;
    if( !i->value.IsInt() )
        return nullopt;
    return i->value.GetInt64();
}

//Document
//GenericDocument<UTF8<> >

VFSNetDropboxHost::VFSNetDropboxHost( const string &_access_token ):
    VFSHost("", nullptr, VFSNetDropboxHost::Tag),
    m_Token(_access_token)
{
    if( m_Token.empty() )
        throw invalid_argument("bad token");
}

int VFSNetDropboxHost::StatFS(const char *_path,
                              VFSStatFS &_stat,
                              const VFSCancelChecker &_cancel_checker)
{
    _stat.total_bytes = 0;
    _stat.free_bytes = 0;
    _stat.avail_bytes = 0;
    _stat.volume_name = "";

    auto session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_GetSpaceUsage];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %s", m_Token.c_str()]
        forHTTPHeaderField:@"Authorization"];

// bad:
//code: 400, headers {
//    Connection = "keep-alive";
//    "Content-Length" = 99;
//    "Content-Type" = "text/plain; charset=utf-8";
//    Date = "Mon, 03 Apr 2017 05:24:27 GMT";
//    Server = nginx;
//    "X-Dropbox-Request-Id" = 741be324f7c5291d075c14d53cb04e9e;
//}


// good:
//code: 200, headers {
//    "Cache-Control" = "no-cache";
//    Connection = "keep-alive";
//    "Content-Encoding" = gzip;
//    "Content-Type" = "application/json";
//    Date = "Mon, 03 Apr 2017 05:23:26 GMT";
//    Pragma = "no-cache";
//    Server = nginx;
//    "Transfer-Encoding" = Identity;
//    Vary = "Accept-Encoding";
//    "X-Content-Type-Options" = nosniff;
//    "X-Dropbox-Http-Protocol" = None;
//    "X-Dropbox-Request-Id" = a688c4a4567d0308c528bcfec9efbb29;
//    "X-Frame-Options" = SAMEORIGIN;
//    "X-Server-Response-Time" = 69;

    NSURLResponse *response;
    auto data = SendSynchonousRequest(session, req, &response, nullptr);
    if( data ) {
        using namespace rapidjson;
        Document json;
        ParseResult ok = json.Parse<kParseNoFlags>( (const char *)data.bytes, data.length );
        if( !ok ) {
            return -1;
        }

        auto used = json["used"].GetInt64();
        auto allocated = json["allocation"]["allocated"].GetInt64();
        
        _stat.total_bytes = allocated;
        _stat.free_bytes = allocated - used;
        _stat.avail_bytes = _stat.free_bytes;

        return 0;
    }

    return VFSError::GenericError;
}

int VFSNetDropboxHost::Stat(const char *_path,
                            VFSStat &_st,
                            int _flags,
                            const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    static const auto file_type = "file"s, folder_type = "folder"s;
    memset( &_st, 0, sizeof(_st) );
    auto session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_GetMetadata];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %s", m_Token.c_str()]
        forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
//@property (nullable, copy) NSData *HTTPBody;
    string body = "{ \"path\": \"" + EscapeString(path) + "\"}";
    [req setHTTPBody:[NSData dataWithBytes:data(body) length:size(body)]];
    
    
    NSURLResponse *response;
    auto data = SendSynchonousRequest(session, req, &response, nullptr);
    
    if( IsNormalJSONResponse(response) && data ) {
        /// ....
//        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

        using namespace rapidjson;
        Document json;
        ParseResult ok = json.Parse<kParseNoFlags>( (const char *)data.bytes, data.length );
        if( !ok ) {
            return VFSError::GenericError;
        }

        const auto type = GetString(json, ".tag");
        if( !type )
            return VFSError::GenericError;
        
        if( file_type == type ) {
            _st.mode = S_IRUSR | S_IWUSR | S_IFREG;
            _st.meaning.mode = true;

            if( auto size = GetLong(json, "size") ) {
                _st.size = *size;
                _st.meaning.size = true;
            }
  
            NSDateFormatter * df = [[NSDateFormatter alloc] init];
            df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
            if( auto mod_date = GetString(json, "server_modified") ) {
                if( auto date = [df dateFromString:[NSString stringWithUTF8String:mod_date]] ) {
                    _st.ctime.tv_sec = date.timeIntervalSince1970;
                    _st.atime = _st.btime = _st.mtime = _st.ctime;
                }
            }

            return 0;
        }
        else if( folder_type == type ) {
            _st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
            _st.meaning.mode = true;

        
            return 0;
        }
    }
    else if( data ) {
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    }
    
    
//{
//    ".tag": "file",
//    "name": "Prime_Numbers.txt",
//    "id": "id:a4ayc_80_OEAAAAAAAAAXw",
//    "client_modified": "2015-05-12T15:50:38Z",
//    "server_modified": "2015-05-12T15:50:38Z",
//    "rev": "a1c10ce0dd78",
//    "size": 7212,
//    "path_lower": "/homework/math/prime_numbers.txt",
//    "path_display": "/Homework/math/Prime_Numbers.txt",
//    "sharing_info": {
//        "read_only": true,
//        "parent_shared_folder_id": "84528192421",
//        "modified_by": "dbid:AAH4f99T0taONIb-OurWxbNQ6ywGRopQngc"
//    },
//    "property_groups": [
//        {
//            "template_id": "ptid:1a5n2i6d3OYEAAAAAAAAAYa",
//            "fields": [
//                {
//                    "name": "Security Policy",
//                    "value": "Confidential"
//                }
//            ]
//        }
//    ],
//    "has_explicit_shared_members": false,
//    "content_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
//}
    
//curl -X POST https://api.dropboxapi.com/2/files/get_metadata \
//    --header "Authorization: Bearer " \
//    --header "Content-Type: application/json" \
//    --data "{\"path\": \"/Homework/math\",\"include_media_info\": false,\"include_deleted\": false,\"include_has_explicit_shared_members\": false}"
    
    
//{
//    "path": "/Homework/math",
//    "include_media_info": false,
//    "include_deleted": false,
//    "include_has_explicit_shared_members": false
//}
    

    return VFSError::GenericError;
}
