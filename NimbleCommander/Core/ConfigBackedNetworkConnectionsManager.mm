// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConfigBackedNetworkConnectionsManager.h"
#include <dirent.h>
#include <NetFS/NetFS.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#pragma clang diagnostic pop
#include <Habanero/algo.h>
#include <Utility/KeychainServices.h>
#include <Utility/NativeFSManager.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>
#include <NimbleCommander/Core/rapidjson.h>

#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>

using namespace nc;

static const auto g_ConfigFilename = "NetworkConnections.json";
static const auto g_ConnectionsKey = "connections";
static const auto g_MRUKey = "mostRecentlyUsed";

static void SortByMRU(vector<NetworkConnectionsManager::Connection> &_values, const vector<boost::uuids::uuid>& _mru)
{
    vector< pair<NetworkConnectionsManager::Connection, decltype(begin(_mru))> > v;
    for( auto &i: _values ) {
        auto it = find( begin(_mru), end(_mru), i.Uuid() );
        v.emplace_back( move(i), it );
    }
    
    sort( begin(v), end(v), [](auto &_1st, auto &_2nd){ return _1st.second < _2nd.second; } );
  
    for( size_t i = 0, e = v.size(); i != e; ++i )
        _values[i] = move( v[i].first );
}

static GenericConfig::ConfigValue FillBasicConnectionInfoInJSONObject(
    const char *_type,
    const NetworkConnectionsManager::BaseConnection &_bc)
{
    auto &alloc = GenericConfig::g_CrtAllocator;
    GenericConfig::ConfigValue cv(rapidjson::kObjectType);

    cv.AddMember("type", GenericConfig::ConfigValue(_type, alloc), alloc);
    cv.AddMember("title", GenericConfig::ConfigValue(_bc.title.c_str(), alloc), alloc);
    cv.AddMember("uuid", GenericConfig::ConfigValue(to_string(_bc.uuid).c_str(), alloc), alloc);
    return cv;
}

static GenericConfig::ConfigValue ConnectionToJSONObject( NetworkConnectionsManager::Connection _c )
{
    auto &alloc = GenericConfig::g_CrtAllocator;
    using value = GenericConfig::ConfigValue;
    
    if( _c.IsType<NetworkConnectionsManager::FTP>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::FTP>();
       
        auto o = FillBasicConnectionInfoInJSONObject("ftp", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("path", value(c.path.c_str(), alloc), alloc);
        o.AddMember("port", value((int)c.port), alloc);
        return o;
    }
    if( _c.IsType<NetworkConnectionsManager::SFTP>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::SFTP>();
        auto o = FillBasicConnectionInfoInJSONObject("sftp", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("keypath", value(c.keypath.c_str(), alloc), alloc);
        o.AddMember("port", value((int)c.port), alloc);
        return o;
    }
    if( _c.IsType<NetworkConnectionsManager::LANShare>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::LANShare>();
        auto o = FillBasicConnectionInfoInJSONObject("lanshare", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("share", value(c.share.c_str(), alloc), alloc);
        o.AddMember("mountpoint", value(c.mountpoint.c_str(), alloc), alloc);
        o.AddMember("proto", value((int)c.proto), alloc);
        return o;
    }
    if( _c.IsType<NetworkConnectionsManager::Dropbox>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::Dropbox>();
        auto o = FillBasicConnectionInfoInJSONObject("dropbox", c);
        o.AddMember("account", value(c.account.c_str(), alloc), alloc);
        return o;
    }
    if( const auto p = _c.Cast<NetworkConnectionsManager::WebDAV>() ) {
        const auto &c = *p;
        auto o = FillBasicConnectionInfoInJSONObject("webdav", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("path", value(c.path.c_str(), alloc), alloc);
        o.AddMember("https", value(c.https), alloc);
        o.AddMember("port", value(c.port), alloc);
        return o;
    }
    
    return GenericConfig::ConfigValue(rapidjson::kNullType);
}

static optional<NetworkConnectionsManager::Connection> JSONObjectToConnection( const GenericConfig::ConfigValue &_object )
{
    static const boost::uuids::string_generator uuid_gen{};
    using namespace rapidjson;
    auto has_string = [&](const char *k){
        if( const auto i = _object.FindMember(k); i != _object.MemberEnd() )
            return i->value.GetType() == kStringType;
        return false;
    };
    auto has_number = [&](const char *k) {
        if( const auto i = _object.FindMember(k); i != _object.MemberEnd() )
            return i->value.GetType() == kNumberType;
        return false;
    };
    auto has_bool   = [&](const char *k) {
        if( const auto i = _object.FindMember(k); i != _object.MemberEnd() )
            return i->value.GetType() == kFalseType || i->value.GetType() == kTrueType;
        return false;
    };

    if( _object.GetType() != kObjectType )
        return nullopt;
    
    if( !has_string("type") || !has_string("title") || !has_string("uuid") )
        return nullopt;

    string type = _object["type"].GetString();
    if( type == "ftp" ) {
        if( !has_string("user") || !has_string("host") ||
            !has_string("path") || !has_number("port") )
            return nullopt;

        NetworkConnectionsManager::FTP c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.path = _object["path"].GetString();
        c.port = _object["port"].GetInt();
        
        return NetworkConnectionsManager::Connection( move(c) );
    }
    else if( type == "sftp" ) {
        if( !has_string("user") || !has_string("host") ||
            !has_string("keypath") || !has_number("port") )
            return nullopt;
        
        NetworkConnectionsManager::SFTP c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.keypath = _object["keypath"].GetString();
        c.port = _object["port"].GetInt();
        
        return NetworkConnectionsManager::Connection( move(c) );
    }
    else if( type == "lanshare" ) {
        if( !has_string("user") || !has_string("host") ||
            !has_string("share") || !has_string("mountpoint") || !has_number("proto") )
            return nullopt;
    
        NetworkConnectionsManager::LANShare c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.share = _object["share"].GetString();
        c.mountpoint = _object["mountpoint"].GetString();
        c.proto = (NetworkConnectionsManager::LANShare::Protocol)_object["proto"].GetInt();

        return NetworkConnectionsManager::Connection( move(c) );
    }
    else if( type == "dropbox" ) {
        if( !has_string("account") )
            return nullopt;

        NetworkConnectionsManager::Dropbox c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.account = _object["account"].GetString();
        
        return NetworkConnectionsManager::Connection( move(c) );
    }
    else if( type == "webdav" ) {
        if( !has_string("user") || !has_string("host") || !has_string("path") ||
            !has_number("port") || !has_bool("https") )
                return nullopt;
        
        NetworkConnectionsManager::WebDAV c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.path = _object["path"].GetString();
        c.https = _object["https"].GetBool();
        c.port = _object["port"].GetInt();
     
        return NetworkConnectionsManager::Connection( move(c) );
    }

    return nullopt;
}

static const string& PrefixForShareProtocol( NetworkConnectionsManager::LANShare::Protocol p )
{
    static const auto smb = "smb"s, afp = "afp"s, nfs = "nfs"s, unknown = ""s;
    if( p == NetworkConnectionsManager::LANShare::Protocol::SMB ) return smb;
    if( p == NetworkConnectionsManager::LANShare::Protocol::AFP ) return afp;
    if( p == NetworkConnectionsManager::LANShare::Protocol::NFS ) return nfs;
    return unknown;
}

static string KeychainWhereFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTP>() )
        return "ftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTP>() )
        return "sftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::LANShare>() )
        return PrefixForShareProtocol(c->proto) + "://" +
            (c->user.empty() ? c->user + "@" : "") +
            c->host + "/" + c->share;
    if( auto c = _c.Cast<NetworkConnectionsManager::Dropbox>() )
        return "dropbox://"s + c->account;
    if( auto c = _c.Cast<NetworkConnectionsManager::WebDAV>() )
        return (c->https ? "https://" : "http://") + c->host + (c->path.empty() ? "" : "/"+c->path);
    return "";
}

static string KeychainAccountFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTP>() )
        return c->user;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTP>() )
        return c->user;
    if( auto c = _c.Cast<NetworkConnectionsManager::LANShare>() )
        return c->user;
    if( auto c = _c.Cast<NetworkConnectionsManager::Dropbox>() )
        return c->account;
    if( auto c = _c.Cast<NetworkConnectionsManager::WebDAV>() )
        return c->user;
    return "";
}

ConfigBackedNetworkConnectionsManager::
ConfigBackedNetworkConnectionsManager(const string &_config_directory):
    m_Config("", _config_directory + g_ConfigFilename),
    m_IsWritingConfig(false)
{
    // Load current configuration
    Load();
    
    // Wire up on-the-fly loading of externally changed config
    m_Config.ObserveMany(m_ConfigObservations, [=]{ if(!m_IsWritingConfig) Load(); },
                         initializer_list<const char*>{g_ConnectionsKey, g_MRUKey}
                         );

    // Wire up notification about application shutdown
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
                                                    m_Config.Commit();
                                                }];
}

ConfigBackedNetworkConnectionsManager::~ConfigBackedNetworkConnectionsManager()
{
}

void ConfigBackedNetworkConnectionsManager::InsertConnection( const NetworkConnectionsManager::Connection &_conn )
{
    LOCK_GUARD(m_Lock) {
        auto t = find_if(begin(m_Connections), end(m_Connections), [&](auto &_c){ return _c.Uuid() == _conn.Uuid(); } );
        if( t != end(m_Connections) )
            *t = _conn;
        else
            m_Connections.emplace_back(_conn);
    }
    dispatch_to_background([=]{ Save(); });
}

void ConfigBackedNetworkConnectionsManager::RemoveConnection( const Connection &_connection )
{
    LOCK_GUARD(m_Lock) {
        auto t = find_if(begin(m_Connections), end(m_Connections), [&](auto &_c){ return _c.Uuid() == _connection.Uuid(); } );
        if( t != end(m_Connections) )
            m_Connections.erase(t);
        
        auto i = find_if(begin(m_MRU), end(m_MRU), [&](auto &_c){ return _c == _connection.Uuid(); } );
        if( i != end(m_MRU) )
            m_MRU.erase(i);
    }
    dispatch_to_background([=]{ Save(); });
}

optional<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::ConnectionByUUID(const boost::uuids::uuid& _uuid) const
{
    lock_guard<mutex> lock(m_Lock);
    auto t = find_if(begin(m_Connections), end(m_Connections), [&](auto &_c){ return _c.Uuid() == _uuid; } );
    if( t != end(m_Connections) )
        return *t;
    return nullopt;
}

void ConfigBackedNetworkConnectionsManager::Save()
{
    GenericConfig::ConfigValue connections(rapidjson::kArrayType);
    GenericConfig::ConfigValue mru(rapidjson::kArrayType);
    LOCK_GUARD(m_Lock) {
        for( auto &c: m_Connections ) {
            auto o = ConnectionToJSONObject(c);
            if( o.GetType() != rapidjson::kNullType )
                connections.PushBack( move(o), GenericConfig::g_CrtAllocator );
        }
        for( auto &u: m_MRU )
            mru.PushBack( GenericConfig::ConfigValue(to_string(u).c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator );
    }

    m_IsWritingConfig = true;
    auto clear = at_scope_end([&]{ m_IsWritingConfig = false; });
    
    m_Config.Set(g_ConnectionsKey, connections);
    m_Config.Set(g_MRUKey, mru);
}

void ConfigBackedNetworkConnectionsManager::Load()
{
    using namespace rapidjson;
    static const boost::uuids::string_generator uuid_gen{};
    LOCK_GUARD(m_Lock) {
        m_Connections.clear();
        m_MRU.clear();
        
        auto connections = m_Config.Get(g_ConnectionsKey);
        if( connections.GetType() == kArrayType )
            for( auto i = connections.Begin(), e = connections.End(); i != e; ++i )
                if( auto c = JSONObjectToConnection(*i) )
                    m_Connections.emplace_back( *c );
        
        auto mru = m_Config.Get(g_MRUKey);
        if( mru.GetType() == kArrayType )
            for( auto i = mru.Begin(), e = mru.End(); i != e; ++i )
                if( i->GetType() == kStringType )
                    m_MRU.emplace_back( uuid_gen(i->GetString()) );
    }
}

void ConfigBackedNetworkConnectionsManager::ReportUsage( const Connection &_connection )
{
    LOCK_GUARD(m_Lock) {
        auto it = find_if( begin(m_MRU), end(m_MRU), [&](auto &i){ return i == _connection.Uuid(); } );
        if( it != end(m_MRU) )
            rotate( begin(m_MRU), it, it + 1 );
        else
            m_MRU.insert( begin(m_MRU), _connection.Uuid() );
    }
    dispatch_to_background([=]{ Save(); });
}

vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::FTPConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Connections)
            if( i.IsType<FTP>() )
                c.emplace_back( i );
        SortByMRU(c, m_MRU);
    }
    return c;
}

vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::SFTPConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Connections)
            if( i.IsType<SFTP>() )
                c.emplace_back( i );
        SortByMRU(c, m_MRU);
    }
    return c;
}

vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::
    LANShareConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Connections)
            if( i.IsType<LANShare>() )
                c.emplace_back( i );
        SortByMRU(c, m_MRU);
    }
    return c;
}

vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::
    AllConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        c = m_Connections;
        SortByMRU(c, m_MRU);
    }
    return c;
}

bool ConfigBackedNetworkConnectionsManager::SetPassword(const Connection &_conn,
                                                        const string& _password)
{
    return KeychainServices::Instance().SetPassword(KeychainWhereFromConnection(_conn),
                                                    KeychainAccountFromConnection(_conn),
                                                    _password);
}

bool ConfigBackedNetworkConnectionsManager::GetPassword(const Connection &_conn,
                                                        string& _password)
{
    return KeychainServices::Instance().GetPassword(KeychainWhereFromConnection(_conn),
                                                    KeychainAccountFromConnection(_conn),
                                                    _password);
}

bool ConfigBackedNetworkConnectionsManager::AskForPassword(const Connection &_conn,
                                                           string& _password)
{
    return RunAskForPasswordModalWindow( TitleForConnection(_conn), _password );
}

optional<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::
    ConnectionForVFS(const VFSHost& _vfs) const
{
    function<bool(const Connection &)> pred;

    if( auto ftp = dynamic_cast<const vfs::FTPHost*>(&_vfs) )
        pred = [ftp](const Connection &i){
            if( auto p = i.Cast<FTP>() )
                return p->host == ftp->ServerUrl() &&
                    p->user == ftp->User() &&
                    p->port == ftp->Port();
            return false;
        };
    else if( auto sftp = dynamic_cast<const vfs::SFTPHost*>(&_vfs) )
        pred = [sftp](const Connection &i){
            if( auto p = i.Cast<SFTP>() )
                return p->host == sftp->ServerUrl() &&
                    p->user == sftp->User() &&
                    p->keypath == sftp->Keypath() &&
                    p->port == sftp->Port();
            return false;
        };
    else if( auto dropbox = dynamic_cast<const vfs::DropboxHost*>(&_vfs) )
        pred = [dropbox](const Connection &i){
            if( auto p = i.Cast<Dropbox>() )
                return p->account == dropbox->Account();
            return false;
        };
    else if( auto webdav = dynamic_cast<const vfs::WebDAVHost*>(&_vfs) )
        pred = [webdav](const Connection &i){
            if( auto p = i.Cast<WebDAV>() )
                return p->host == webdav->Host() &&
                    p->path == webdav->Path() &&
                    p->user == webdav->Username();
            return false;
        };
    
    if( !pred )
        return nullopt;
    
    LOCK_GUARD(m_Lock) {
        const auto it = find_if( begin(m_Connections), end(m_Connections), pred );
        if( it != end(m_Connections) )
            return *it;
    }
    
    return nullopt;
}

VFSHostPtr ConfigBackedNetworkConnectionsManager::SpawnHostFromConnection
    (const Connection &_connection, bool _allow_password_ui)
{
    string passwd;
    bool shoud_save_passwd = false;
    if( !GetPassword(_connection, passwd) ) {
        if( !_allow_password_ui || !AskForPassword(_connection, passwd) )
            return nullptr;
        shoud_save_passwd = true;
    }
    
    VFSHostPtr host;
    if( auto ftp = _connection.Cast<FTP>() )
        host = make_shared<vfs::FTPHost>( ftp->host, ftp->user, passwd, ftp->path, ftp->port );
    else if( auto sftp = _connection.Cast<SFTP>() )
        host = make_shared<vfs::SFTPHost>( sftp->host, sftp->user, passwd, sftp->keypath, sftp->port );
    else if( auto dropbox = _connection.Cast<Dropbox>() )
        host = make_shared<vfs::DropboxHost>( dropbox->account, passwd );
    else if( auto w = _connection.Cast<WebDAV>() )
        host = make_shared<vfs::WebDAVHost>( w->host, w->user, passwd, w->path, w->https, w->port );
    
    if( host ) {
        ReportUsage(_connection);
        if( shoud_save_passwd )
            SetPassword(_connection, passwd);
    }
    return host;
}

static string NetFSErrorString( int _code )
{
    if( _code > 0 ) {
        NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:_code userInfo:nil];
        if( err && err.localizedFailureReason.UTF8String)
            return err.localizedFailureReason.UTF8String;
        else
            return "Unknown error";
    }
    else if( _code < 0 ) {
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:_code userInfo:nil];
        if( err && err.localizedFailureReason.UTF8String)
            return err.localizedFailureReason.UTF8String;
        else
            return "Unknown error";
    }
    return "Unknown error";
}

void ConfigBackedNetworkConnectionsManager::NetFSCallback
    (int _status, void *_requestID, CFArrayRef _mountpoints)
{
    function<void(const string&_mounted_path, const string&_error)> cb;
    LOCK_GUARD(m_PendingMountRequestsLock) {
        auto i = find_if(begin(m_PendingMountRequests), end(m_PendingMountRequests), [=](auto &_v){
            return _v.first == _requestID;
        });
        if( i != end(m_PendingMountRequests) ) {
            cb = move(i->second);
            m_PendingMountRequests.erase(i);
        }
    }
    
    if( cb ) {
        // _mountpoints can contain a valid mounted path even if _status is not equal to zero
        if( _mountpoints != nullptr && CFArrayGetCount(_mountpoints) != 0 )
            if( auto str = objc_cast<NSString>(((__bridge NSArray*)_mountpoints).firstObject) ){
                string path = str.fileSystemRepresentationSafe;
                if( !path.empty() ) {
                    cb(path, "");
                    return;
                }
            }
        cb( "", NetFSErrorString(_status) );
    }
}

static NSURL* CookURLForLANShare( const NetworkConnectionsManager::LANShare &_share )
{
    const auto url_string = PrefixForShareProtocol(_share.proto) +
                            "://" +
                            _share.host + "/" +
                            _share.share;
    const auto cocoa_url_string = [NSString stringWithUTF8StdString:url_string];
    if( !cocoa_url_string )
        return nil;
    
    return [NSURL URLWithString:cocoa_url_string];
}

static NSURL* CookMountPointForLANShare( const NetworkConnectionsManager::LANShare &_share )
{
    if( _share.mountpoint.empty() )
        return nil;
    
    const auto url_string = [NSString stringWithUTF8StdString:_share.mountpoint];
    if( !url_string )
        return nil;
    
    return [NSURL URLWithString:url_string];
}

/**
 * Return true if _path is a directory and it is empty.
 */
static bool IsEmptyDirectory(const string &_path)
{
    if( DIR *dir = opendir( _path.c_str() ) ) {
        int n = 0;
        while( readdir(dir) != nullptr )
            if( ++n > 2 )
                break;
        closedir(dir);
        return n <= 2;
    }
    return false;
}

static bool TearDownSMBOrAFPMountName
    ( const string &_name, string &_user, string &_host, string &_share )
{
    auto url_string = [NSString stringWithUTF8StdString:_name];
    if( !url_string )
        return false;

    NSURL *url = [NSURL URLWithString:url_string];
    if( !url )
        return false;

    if( !url.host || !url.path )
        return false;

    _host = url.host.UTF8String; // 192.168.2.5
    _share = url.path.UTF8String; // i.e. /iTunesMusic
    if( !_share.empty() ) _share.erase( begin(_share) ); // i.e. iTunesMusic
    
    if( url.user )
        _user = url.user.UTF8String;
    else
        _user = "";

    return true;
}

static bool TearDownNFSMountName( const string &_name, string &_host, string &_share )
{
    static const auto delimiter = ":/"s;
    auto pos = _name.find( delimiter );
    if( pos == _name.npos )
        return false;
    _host = _name.substr( 0, pos );
    _share = _name.substr( pos + delimiter.size() );
    return true;
}

static vector<shared_ptr<const NativeFileSystemInfo>> GetMountedRemoteFilesystems()
{
    static const auto smb = "smbfs"s, afp = "afpfs"s, nfs = "nfs"s;
    vector<shared_ptr<const NativeFileSystemInfo>> remotes;
    
    for( const auto &v: NativeFSManager::Instance().Volumes() ) {
        const auto &volume = *v;

        // basic discarding check on volume
        if( volume.mount_flags.internal || volume.mount_flags.local )
            continue;
        
        // treat only these filesystems as remote
        if( volume.fs_type_name == smb ||
            volume.fs_type_name == afp ||
            volume.fs_type_name == nfs ) {
            remotes.emplace_back(v);
        }
    }

    return remotes;
}

static bool MatchVolumeWithShare
    ( const NativeFileSystemInfo& _volume, const NetworkConnectionsManager::LANShare &_share )
{
    static const auto smb = "smbfs"s, afp = "afpfs"s, nfs = "nfs"s;
    using protocols = NetworkConnectionsManager::LANShare::Protocol;
    if( (_share.proto == protocols::SMB && _volume.fs_type_name == smb) ||
        (_share.proto == protocols::AFP && _volume.fs_type_name == afp) ) {
        string user, host, share;
        if( TearDownSMBOrAFPMountName(_volume.mounted_from_name, user, host, share) ) {
            auto same_host =  strcasecmp( host.c_str(),  _share.host.c_str() ) == 0;
            auto same_share = strcasecmp( share.c_str(), _share.share.c_str()) == 0;
            auto same_user = (strcasecmp( user.c_str(),  _share.user.c_str() ) == 0) ||
                             (_share.user.empty() && user == "GUEST") ||
                             (_share.user.empty() && user == "guest") ;
            return same_host && same_share && same_user;
        }
    }
    else if( _share.proto == protocols::NFS && _volume.fs_type_name == nfs ) {
        string host, share;
        if( TearDownNFSMountName(_volume.mounted_from_name, host, share ) ) {
            auto same_host =  strcasecmp( host.c_str(),  _share.host.c_str() ) == 0;
            auto same_share = strcasecmp( share.c_str(), _share.share.c_str()) == 0;
            return same_host && same_share;
        }
    }
    return false;
}

static shared_ptr<const NativeFileSystemInfo> FindExistingMountedShare
    (const NetworkConnectionsManager::LANShare &_share)
{
    for( auto &v: GetMountedRemoteFilesystems() )
        if( MatchVolumeWithShare(*v, _share) )
            return v;
    return nullptr;
}

bool ConfigBackedNetworkConnectionsManager::MountShareAsync(
    const Connection &_conn,
    const string &_password,
    function<void(const string&_mounted_path, const string&_error)> _callback)
{
    if( !_conn.IsType<LANShare>() )
        return false;
    
    const auto conn = _conn;
    const auto &share = conn.Get<LANShare>();
    
    if( const auto v = FindExistingMountedShare(share) ) {
        // we already have this share mounted - just return it.
        // mount path may be different although
        dispatch_to_main_queue([v, _callback]{
            _callback( v->mounted_at_path, "" );
        });
        return true;
    }

    auto url = CookURLForLANShare(share);
    auto mountpoint = CookMountPointForLANShare(share);
    auto username = share.user.empty() ? nil : [NSString stringWithUTF8StdString:share.user];
    auto passwd = _password.empty() ? nil : [NSString stringWithUTF8StdString:_password];
    auto open_options = (NSMutableDictionary *)[@{@"UIOption": @"NoUI"} mutableCopy];
    auto mount_options = (!mountpoint || !IsEmptyDirectory(share.mountpoint)) ? nil :
        (NSMutableDictionary *)[@{@"MountAtMountDir": @true} mutableCopy];
    
    auto callback = [this](int status, AsyncRequestID requestID, CFArrayRef mountpoints) {
        NetFSCallback(status, requestID, mountpoints);
    };
    
    AsyncRequestID request_id;
    int result = NetFSMountURLAsync((__bridge CFURLRef)url,
                                    (__bridge CFURLRef)mountpoint,
                                    (__bridge CFStringRef)username,
                                    (__bridge CFStringRef)passwd,
                                    (__bridge CFMutableDictionaryRef)open_options,
                                    (__bridge CFMutableDictionaryRef)mount_options,
                                    &request_id,
                                    dispatch_get_main_queue(),
                                    callback);
    
    if( result != 0 ) {
        auto error = NetFSErrorString(result);
         dispatch_to_main_queue([error, _callback]{
            _callback( "", error );
        });
        return false;
    }
    
    LOCK_GUARD(m_PendingMountRequestsLock) {
        m_PendingMountRequests.emplace_back( request_id, move(_callback) );
    }
    
    return true;
}
