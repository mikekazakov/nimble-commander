// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <string>
#include <sys/stat.h>

namespace nc::vfs::webdav {

class Connection;


class HostConfiguration
{
public:
    std::string  server_url;
    std::string  user;
    std::string  passwd;
    std::string  path;
    std::string  verbose; // cached only. not counted in operator ==
    std::string  full_url; // http[s]://server:port/base_path/
    bool    https;
    int     port;
    
    const char *Tag() const;
    const char *Junction() const;
    const char *VerboseJunction() const;
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
    std::string filename;
    long size = -1;
    time_t creation_date = -1;
    time_t modification_date = -1;
    bool is_directory = false;    
};

constexpr uint16_t DirectoryAccessMode = S_IRUSR | S_IWUSR | S_IFDIR | S_IXUSR;
constexpr uint16_t RegularFileAccessMode = S_IRUSR | S_IWUSR | S_IFREG;
    
int ToVFSError( int _curl_rc, int _http_rc ) noexcept;
    
int curl_easy_get_response_code(CURL *_handle);

}
