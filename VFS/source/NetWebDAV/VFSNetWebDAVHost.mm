#include "VFSNetWebDAVHost.h"
#include "Internal.h"
#include <Utility/PathManip.h>
#include "../VFSListingInput.h"
#include "ConnectionsPool.h"
#include "Cache.h"

namespace nc::vfs {

using namespace webdav;

const char *WebDAVHost::UniqueTag = "net_webdav";

struct WebDAVHost::State
{
    State( const HostConfiguration &_config ):
        m_Pool{_config}
    {}
    
    ConnectionsPool m_Pool;
    Cache           m_Cache;
};

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
    VFSHost(_serv_url.c_str(), nullptr, UniqueTag),
    m_Configuration( ComposeConfiguration(_serv_url, _user, _passwd, _path, _https, _port) )
{

//    inst->curl = curl_easy_init();


//    FetchDAVListing(Config(), "/");
    I.reset( new State{Config()} );
//    I->m_Pool.Return


    auto ar = I->m_Pool.Get();
    auto [rc, requests] = FetchServerOptions( Config(), *ar.connection );
    if( rc != CURLE_OK ) {   
        throw rc;
    }
    if( (requests & HTTPRequests::MinimalRequiredSet) !=  HTTPRequests::MinimalRequiredSet ) {
        HTTPRequests::Print(requests);
        throw VFSErrorException( VFSError::FromErrno(EPROTONOSUPPORT) );
    }
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

    const auto path =  EnsureTrailingSlash(_path);
    
    if( _flags & VFSFlags::F_ForceRefresh )
        I->m_Cache.DiscardListing(path);
    
    vector<PropFindResponse> items;
    if( auto cached = I->m_Cache.Listing(path) ) {
        items = move( *cached );
    }
    else {
        const auto refresh_rc = RefreshListingAtPath(path, _cancel_checker);
        if( refresh_rc != VFSError::Ok )
            return refresh_rc;
        
        if( auto cached = I->m_Cache.Listing(path) )
            items = move( *cached );
        else
            return VFSError::GenericError;
    }

    if( _flags & VFSFlags::F_NoDotDot ) {
        items.erase( remove_if(begin(items), end(items), [](const auto &_item){
            return _item.filename == "..";
        }), end(items));
    }
    else {
        partition( begin(items), end(items), [](const auto &_i){
            return _i.filename == "..";
        
        });
    }

    VFSListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] =  path;
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::sparse );
    listing_source.ctimes.reset( variable_container<>::type::sparse );
    listing_source.mtimes.reset( variable_container<>::type::sparse );

    int index = 0;
    for( auto &e: items ) {
        listing_source.filenames.emplace_back( e.filename );
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

int WebDAVHost::Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;


    PropFindResponse item;
    if( auto cached = I->m_Cache.Item(_path) ) {
        item = move(*cached);
    }
    else {
        const auto [directory, filename] =  DeconstructPath(_path);
        if( directory.empty() )
            return VFSError::InvalidCall;
        const auto rc = RefreshListingAtPath(directory, _cancel_checker);
        if( rc != VFSError::Ok )
            return rc;
        
        if( auto cached = I->m_Cache.Item(_path) )
            item = move(*cached);
        else
            return VFSError::GenericError;
    }
    
    memset( &_st, 0, sizeof(_st) );
    _st.mode = item.is_directory ? DirectoryAccessMode : RegularFileAccessMode;
    if( item.size >= 0 ) {
        _st.size = item.size;
        _st.meaning.size = 1;
    }
    if( item.creation_date >= 0 ) {
        _st.btime.tv_sec = item.creation_date;
        _st.meaning.btime = true;
    }
    if( item.modification_date >= 0 ) {
        _st.mtime.tv_sec = _st.ctime.tv_sec = item.modification_date;
        _st.meaning.mtime = _st.meaning.ctime = true;
    }
        
    return VFSError::Ok;
}


int WebDAVHost::RefreshListingAtPath( const string &_path, const VFSCancelChecker &_cancel_checker )
{
    if( _path.back() != '/' )
        throw invalid_argument("RefreshListingAtPath requires a path with a trailing slash");
    
    auto ar = I->m_Pool.Get();
    auto [fetch_rc, fetch_items] = FetchDAVListing(Config(), *ar.connection, _path);
    if( fetch_rc != CURLE_OK ) {
        return CURlErrorToVFSError(fetch_rc);
    }

    I->m_Cache.CommitListing( _path, move(fetch_items) );
    
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
