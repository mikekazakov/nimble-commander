#pragma once

#include "../../../Files/3rd_party/built/include/curl/curl.h"

namespace nc::vfs::webdav {

class Connection;


class HostConfiguration
{
public:
    string server_url;
    string user;
    string passwd;
    string path;
//    string verbose; // cached only. not counted in operator ==
    string full_url; // http[s]://server:port/base_path/
    bool https;
    int   port;
        
    const char *Tag() const;
    const char *Junction() const;
    bool operator==(const HostConfiguration&_rhs) const;
};

namespace HTTPRequests {
    using Mask = int;
    enum {
        None       = 0x0000,
        Get        = 0x0001,
        Head       = 0x0002,
        Post       = 0x0004,
        Put        = 0x0008,
        Delete     = 0x0010,
        Connect    = 0x0020,
        Options    = 0x0040,
        Trace      = 0x0080,
        Copy       = 0x0100,
        Lock       = 0x0200,
        Unlock     = 0x0400,
        Mkcol      = 0x0800,
        Move       = 0x1000,
        PropFind   = 0x2000,
        PropPatch  = 0x4000
    };
    
    enum {
//        MinimalRequiredSet = Get | Put | PropFind | PropPatch | Mkcol
        MinimalRequiredSet = Get | PropFind | PropPatch
    };
    void Print( Mask _mask );
};

struct PropFindResponse
{
    string filename;
    long size = -1;
    time_t creation_date = -1;
    time_t modification_date = -1;
    bool is_directory = false;    
};

constexpr uint16_t DirectoryAccessMode = S_IRUSR | S_IWUSR | S_IFDIR | S_IXUSR;
constexpr uint16_t RegularFileAccessMode = S_IRUSR | S_IWUSR | S_IFREG;


pair<int, HTTPRequests::Mask> FetchServerOptions(const HostConfiguration& _options,
                                                 Connection &_connection );

// curle, free space, used space
tuple<int, long, long> FetchSpaceQuota(const HostConfiguration& _options,
                                       Connection &_connection );
    
pair<int, vector<PropFindResponse>> FetchDAVListing(const HostConfiguration& _options,
                                                    Connection &_connection,
                                                    const string &_path );
pair<string, string> DeconstructPath(const string &_path);
int CURlErrorToVFSError( int _curle );
    
string URIEscape( const string &_unescaped );
string URIUnescape( const string &_escaped );


}
