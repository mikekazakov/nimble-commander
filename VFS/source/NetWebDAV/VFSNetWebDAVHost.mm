#include "VFSNetWebDAVHost.h"
#include "Internal.h"
#include <Utility/PathManip.h>
#include "../VFSListingInput.h"

namespace nc::vfs {

using namespace webdav;

const char *WebDAVHost::Tag = "net_webdav";


static VFSConfiguration ComposeConfiguration(const string &_serv_url,
                                             const string &_user,
                                             const string &_passwd,
                                             const string &_path,
                                             bool _https,
                                             int _port);

WebDAVHost::WebDAVHost(const string &_serv_url,
                       const string &_user,
                       const string &_passwd,
                       const string &_path,
                       bool _https,
                       int _port):
    VFSHost(_serv_url.c_str(), nullptr, Tag),
    m_Configuration( ComposeConfiguration(_serv_url, _user, _passwd, _path, _https, _port) )
{
    auto [rc, requests] = FetchServerOptions( Config() );
    if( rc != CURLE_OK ) {
        
        throw rc;
    }
    if( (requests & HTTPRequests::MinimalRequiredSet) !=  HTTPRequests::MinimalRequiredSet ) {
        HTTPRequests::Print(requests);
        throw VFSErrorException( VFSError::FromErrno(EPROTONOSUPPORT) );
    }

//    inst->curl = curl_easy_init();


//    FetchDAVListing(Config(), "/");
}

WebDAVHost::~WebDAVHost()
{
}

const HostConfiguration &WebDAVHost::Config() const noexcept
{
    return m_Configuration.GetUnchecked<webdav::HostConfiguration>();
}

int WebDAVHost::FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> &_target,
                                      int _flags,
                                      const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;

    string path =  EnsureTrailingSlash(_path);
    
    auto [fetch_rc, fetch_items] = FetchDAVListing(Config(), path);
    if( fetch_rc != CURLE_OK ) {
        return CURlErrorToVFSError(fetch_rc);
    }

    if( _flags & VFSFlags::F_NoDotDot )
        fetch_items.erase( remove_if(begin(fetch_items), end(fetch_items), [](const auto &_item){
            return _item.path == "..";
        }), end(fetch_items));


    VFSListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] =  path;
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::sparse );
    listing_source.ctimes.reset( variable_container<>::type::sparse );
    listing_source.mtimes.reset( variable_container<>::type::sparse );

    int index = 0;
    for( auto &e: fetch_items ) {
        listing_source.filenames.emplace_back( e.path );
        listing_source.unix_modes.emplace_back( e.is_directory ?
                                               DirectoryAccessMode :
                                               RegularFileAccessMode );
        listing_source.unix_types.emplace_back( e.is_directory ? DT_DIR : DT_REG );
        if( e.size >= 0 )
            listing_source.sizes.insert( index, e.size );
        if( e.creation_date >= 0 )
            listing_source.btimes.insert( index, e.creation_date );
        if( e.modification_date >= 0 ) {
            listing_source.ctimes.insert( index, e.modification_date );
            listing_source.mtimes.insert( index, e.modification_date );
        }
        index++;
    }

    _target = VFSListing::Build(move(listing_source));
    return VFSError::Ok;
}

static VFSConfiguration ComposeConfiguration(const string &_serv_url,
                                             const string &_user,
                                             const string &_passwd,
                                             const string &_path,
                                             bool _https,
                                             int    _port)
{
    if( _port < 0 )
        _port = _https ? 443 : 80;

    HostConfiguration config;
    config.server_url = _serv_url;
    config.user = _user;
    config.passwd = _passwd;
    config.path = _path;
    config.https = _https;
    config.port = _port;
//    config.verbose = "ftp://"s + (config.user.empty() ? "" : config.user + "@" ) + config.server_url;

    config.full_url = (_https ? "https://"s : "http://"s) +
                      _serv_url +
                      ":"s + to_string(_port) +
                      "/" + _path + "/";

    return VFSConfiguration( move(config) );
}

}
