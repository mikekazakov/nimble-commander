#include <NetFS/NetFS.h>
#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <Habanero/algo.h>
#include <Utility/KeychainServices.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "NetworkConnectionsManager.h"
#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>

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

static void FillBasicConnectionInfoInJSONObject( GenericConfig::ConfigValue &_cv, const char *_type, const NetworkConnectionsManager::BaseConnection &_bc)
{
    _cv.AddMember("type", GenericConfig::ConfigValue(_type, GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
    _cv.AddMember("title", GenericConfig::ConfigValue(_bc.title.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
    _cv.AddMember("uuid", GenericConfig::ConfigValue(to_string(_bc.uuid).c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
}

static GenericConfig::ConfigValue ConnectionToJSONObject( NetworkConnectionsManager::Connection _c )
{
    if( _c.IsType<NetworkConnectionsManager::FTPConnection>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::FTPConnection>();
       
        GenericConfig::ConfigValue o(rapidjson::kObjectType);
        FillBasicConnectionInfoInJSONObject(o, "ftp", c);
        o.AddMember("user", GenericConfig::ConfigValue(c.user.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
        o.AddMember("host", GenericConfig::ConfigValue(c.host.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
        o.AddMember("path", GenericConfig::ConfigValue(c.path.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
        o.AddMember("port", GenericConfig::ConfigValue((int)c.port), GenericConfig::g_CrtAllocator);
        return o;
    }
    if( _c.IsType<NetworkConnectionsManager::SFTPConnection>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::SFTPConnection>();

        GenericConfig::ConfigValue o(rapidjson::kObjectType);
        FillBasicConnectionInfoInJSONObject(o, "sftp", c);
        o.AddMember("user", GenericConfig::ConfigValue(c.user.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
        o.AddMember("host", GenericConfig::ConfigValue(c.host.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
        o.AddMember("keypath", GenericConfig::ConfigValue(c.keypath.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator);
        o.AddMember("port", GenericConfig::ConfigValue((int)c.port), GenericConfig::g_CrtAllocator);
        return o;
    }
    return GenericConfig::ConfigValue(rapidjson::kNullType);
}

static optional<NetworkConnectionsManager::Connection> JSONObjectToConnection( const GenericConfig::ConfigValue &_object )
{
    static const boost::uuids::string_generator uuid_gen{};
    using namespace rapidjson;
    auto has_string = [&](const char *_key){ return _object.HasMember(_key) && _object[_key].GetType() == kStringType; };
    auto has_number = [&](const char *_key){ return _object.HasMember(_key) && _object[_key].GetType() == kNumberType; };
    

    if( _object.GetType() != kObjectType )
        return nullopt;
    
    if( !has_string("type") || !has_string("title") || !has_string("uuid") )
        return nullopt;

    string type = _object["type"].GetString();
    if( type == "ftp" ) {
        if( !has_string("user") || !has_string("host") || !has_string("path") || !has_number("port") )
            return nullopt;

        NetworkConnectionsManager::FTPConnection c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.path = _object["path"].GetString();
        c.port = _object["port"].GetInt();
        
        return NetworkConnectionsManager::Connection( move(c) );
    }
    else if( type == "sftp" ) {
        if( !has_string("user") || !has_string("host") || !has_string("keypath") || !has_number("port") )
            return nullopt;
        
        NetworkConnectionsManager::SFTPConnection c;
        c.uuid = uuid_gen( _object["uuid"].GetString() );
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.keypath = _object["keypath"].GetString();
        c.port = _object["port"].GetInt();
        
        return NetworkConnectionsManager::Connection( move(c) );
    }
    return nullopt;
}

static const string& PrefixForShareProtocol( NetworkConnectionsManager::LANShare::Protocol p )
{
    static const auto smb = "smb"s, afp = "afp"s, unknown = ""s;
    if( p == NetworkConnectionsManager::LANShare::Protocol::SMB ) return smb;
    if( p == NetworkConnectionsManager::LANShare::Protocol::AFP ) return afp;
    return unknown;
}

static string KeychainWhereFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTPConnection>() )
        return "ftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTPConnection>() )
        return "sftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::LANShare>() )
        return PrefixForShareProtocol(c->proto) + "://" +
            (c->user.empty() ? c->user + "@" : "") +
            c->host + "/" + c->share;
    return "";
}

static string KeychainAccountFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTPConnection>() )
        return c->user;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTPConnection>() )
        return c->user;
    if( auto c = _c.Cast<NetworkConnectionsManager::LANShare>() )
        return c->user;
    return "";
}

NetworkConnectionsManager::NetworkConnectionsManager():
    m_Config("", AppDelegate.me.configDirectory + g_ConfigFilename),
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

NetworkConnectionsManager& NetworkConnectionsManager::Instance()
{
    static auto inst = new NetworkConnectionsManager;
    return *inst;
}

boost::uuids::uuid NetworkConnectionsManager::MakeUUID()
{
    static spinlock lock;
    static boost::uuids::basic_random_generator<boost::mt19937> gen;

    lock_guard<spinlock> guard(lock);
    return gen();
}

void NetworkConnectionsManager::InsertConnection( const NetworkConnectionsManager::Connection &_conn )
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

void NetworkConnectionsManager::RemoveConnection( const Connection &_connection )
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

optional<NetworkConnectionsManager::Connection> NetworkConnectionsManager::ConnectionByUUID(const boost::uuids::uuid& _uuid) const
{
    lock_guard<mutex> lock(m_Lock);
    auto t = find_if(begin(m_Connections), end(m_Connections), [&](auto &_c){ return _c.Uuid() == _uuid; } );
    if( t != end(m_Connections) )
        return *t;
    return nullopt;
}

void NetworkConnectionsManager::Save()
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

void NetworkConnectionsManager::Load()
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

string NetworkConnectionsManager::TitleForConnection(const Connection &_conn)
{
    string title_prefix = _conn.Title().empty() ? "" : _conn.Title() + " - ";
    
    if( auto ftp = _conn.Cast<FTPConnection>() ) {
        if(!ftp->user.empty())
            return title_prefix + "ftp://" + ftp->user + "@" + ftp->host;
        else
            return title_prefix + "ftp://" + ftp->host;
    }
    if( auto sftp = _conn.Cast<SFTPConnection>() ) {
        return title_prefix + "sftp://" + sftp->user + "@" + sftp->host;
    }
    if( auto share = _conn.Cast<NetworkConnectionsManager::LANShare>() ) {
        if( share->user.empty() )
            return title_prefix + PrefixForShareProtocol(share->proto) + "://" +
                share->host + "/" + share->share;
        else
            return title_prefix + PrefixForShareProtocol(share->proto) + "://" +
                share->user + "@" + share->host + "/" + share->share;
    }
    return title_prefix;
}

void NetworkConnectionsManager::ReportUsage( const Connection &_connection )
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

vector<NetworkConnectionsManager::Connection> NetworkConnectionsManager::FTPConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Connections)
            if( i.IsType<FTPConnection>() )
                c.emplace_back( i );
        SortByMRU(c, m_MRU);
    }
    return c;
}

vector<NetworkConnectionsManager::Connection> NetworkConnectionsManager::SFTPConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        for(auto &i: m_Connections)
            if( i.IsType<SFTPConnection>() )
                c.emplace_back( i );
        SortByMRU(c, m_MRU);
    }
    return c;
}

vector<NetworkConnectionsManager::Connection> NetworkConnectionsManager::AllConnectionsByMRU() const
{
    vector<Connection> c;
    LOCK_GUARD(m_Lock) {
        c = m_Connections;
        SortByMRU(c, m_MRU);
    }
    return c;
}

bool NetworkConnectionsManager::SetPassword(const Connection &_conn, const string& _password)
{
    return KeychainServices::Instance().SetPassword(KeychainWhereFromConnection(_conn),
                                                    KeychainAccountFromConnection(_conn),
                                                    _password);
}

bool NetworkConnectionsManager::GetPassword(const Connection &_conn, string& _password)
{
    return KeychainServices::Instance().GetPassword(KeychainWhereFromConnection(_conn),
                                                    KeychainAccountFromConnection(_conn),
                                                    _password);
}

bool NetworkConnectionsManager::AskForPassword(const Connection &_conn, string& _password)
{
//    return RunAskForPasswordModalWindow( ResourceNameForUIFromConnection(_conn), _password);
    return RunAskForPasswordModalWindow( TitleForConnection(_conn), _password);
}

optional<NetworkConnectionsManager::Connection> NetworkConnectionsManager::ConnectionForVFS(const VFSHost& _vfs) const
{
    if( auto ftp = dynamic_cast<const VFSNetFTPHost*>(&_vfs) ) {
        LOCK_GUARD(m_Lock) {
            auto it = find_if( begin(m_Connections), end(m_Connections), [&](const Connection &i){
                if( auto p = i.Cast<FTPConnection>() )
                    return p->host == ftp->ServerUrl() && p->user == ftp->User() && p->port == ftp->Port();
                return false;
            } );
            if( it != end(m_Connections) )
                return *it;
        }
    }
    else if( auto sftp = dynamic_cast<const VFSNetSFTPHost*>(&_vfs) ) {
        LOCK_GUARD(m_Lock) {
            auto it = find_if( begin(m_Connections), end(m_Connections), [&](const Connection &i){
                if( auto p = i.Cast<SFTPConnection>() )
                    return p->host == sftp->ServerUrl() && p->user == sftp->User() && p->keypath == sftp->Keypath() && p->port == sftp->Port();
                return false;
            });
            if( it != end(m_Connections) )
                return *it;
        }
    }
    return nullopt;
}

VFSHostPtr NetworkConnectionsManager::SpawnHostFromConnection(const Connection &_connection, bool _allow_password_ui)
{
    string passwd;
    bool shoud_save_passwd = false;
    if( !GetPassword(_connection, passwd) ) {
        if( !_allow_password_ui || !AskForPassword(_connection, passwd) )
            return nullptr;
        shoud_save_passwd = true;
    }
    
    try {
        VFSHostPtr host;
        if( auto *ftp = _connection.Cast<FTPConnection>() )
            host = make_shared<VFSNetFTPHost>( ftp->host, ftp->user, passwd, ftp->path, ftp->port );
        if( auto *sftp = _connection.Cast<SFTPConnection>() )
            host = make_shared<VFSNetSFTPHost>( sftp->host, sftp->user, passwd, sftp->keypath, sftp->port );
        
        if( host ) {
            ReportUsage(_connection);
            if( shoud_save_passwd )
                SetPassword(_connection, passwd);
            return host;
        }
    }
    catch (VFSErrorException &ee) {
    }
    return nullptr;
}


/*
 * NetFSMountURLAsync is the same as NetFSMountURLSync except it does the
 * mount asynchronously.  If the mount_report block is non-NULL, at
 * the completion of the mount it is submitted to the dispatch queue
 * with the result of the mount, the request ID and an array of POSIX mountpoint paths.
 * The request ID can be used by NetFSMountURLCancel() to cancel
 * a pending mount request. The NetFSMountURLBlock is not submitted if
 * the request is cancelled.
 *
 * The return result is as described above for NetFSMountURLSync().
 */
//int
//NetFSMountURLAsync(
//	CFURLRef url,				// URL to mount, e.g. nfs://server/path
//	CFURLRef mountpath,			// Path for the mountpoint
//	CFStringRef user,			// Auth user name (overrides URL)
//	CFStringRef passwd, 			// Auth password (overrides URL)
//	CFMutableDictionaryRef open_options,	// Options for session open (see below)
//	CFMutableDictionaryRef mount_options,	// Options for mounting (see below)
//	AsyncRequestID *requestID,		// ID of this pending request (see cancel)
//	dispatch_queue_t dispatchq,		// Dispatch queue for the block
//	NetFSMountURLBlock mount_report)	// Called at mount completion


/*
 * This is the block called at completion of NetFSMountURLAsync
 * The block receives the mount status (described above), the request ID
 * that was used for the mount, and an array of mountpoint paths.
 */
//typedef	void (^NetFSMountURLBlock)(int status, AsyncRequestID requestID, CFArrayRef mountpoints);

//typedef void * AsyncRequestID;

 /**
 * A positive non-zero return value represents an errno value
 * (see /usr/include/sys/errno.h).  For instance, a missing mountpoint
 * error will be returned as ENOENT (2).
 *
 * A negative non-zero return value represents an OSStatus error.
 * For instance, error -128 is userCanceledErr, returned when a mount
 * operation is canceled by the user. These OSStatus errors are
 * extended to include:
 *
 *  from this header:
 *	ENETFSPWDNEEDSCHANGE		-5045
 *	ENETFSPWDPOLICY			-5046
 *	ENETFSACCOUNTRESTRICTED		-5999
 *	ENETFSNOSHARESAVAIL		-5998
 *	ENETFSNOAUTHMECHSUPP		-5997
 *	ENETFSNOPROTOVERSSUPP		-5996
 *
 *  from <NetAuth/NetAuthErrors.h>
 *	kNetAuthErrorInternal		-6600
 *	kNetAuthErrorMountFailed	-6602
 *	kNetAuthErrorNoSharesAvailable	-6003
 *	kNetAuthErrorGuestNotSupported	-6004
 *	kNetAuthErrorAlreadyClosed	-6005
 *
 */

//#include <NetAuth/NetAuthErrors.h>

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

void NetworkConnectionsManager::NetFSCallback
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
        if( _status == 0 )
            if( CFArrayGetCount(_mountpoints) != 0 )
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

bool NetworkConnectionsManager::MountShareAsync(
    const Connection &_conn,
    const string &_password,
    function<void(const string&_mounted_path, const string&_error)> _callback)
{
    if( !_conn.IsType<LANShare>() )
        return false;
    
    auto conn = _conn;
    auto &share = conn.Get<LANShare>();

    auto url = CookURLForLANShare(share);
    auto mountpoint = CookMountPointForLANShare(share);
    auto username = share.user.empty() ? nil : [NSString stringWithUTF8StdString:share.user];
    auto passwd = _password.empty() ? nil : [NSString stringWithUTF8StdString:_password];
    auto open_options = (NSMutableDictionary *)[@{@"UIOption": @"NoUI"} mutableCopy];
    
//#define kNetFSUseGuestKey		CFSTR("Guest")    
    
    auto callback = [this](int status, AsyncRequestID requestID, CFArrayRef mountpoints) {
        NetFSCallback(status, requestID, mountpoints);
    };
    
    AsyncRequestID request_id;
    int result = NetFSMountURLAsync(
                       (__bridge CFURLRef)url,
                       (__bridge CFURLRef)mountpoint,			// Path for the mountpoint
                       (__bridge CFStringRef)username,
                       (__bridge CFStringRef)passwd,
                       (__bridge CFMutableDictionaryRef)open_options,	// Options for session open (see below)
                       nullptr,	// Options for mounting (see below)
                       &request_id,		// ID of this pending request (see cancel)
                       dispatch_get_main_queue(),		// Dispatch queue for the block
                       callback);	// Called at mount completion
    
    if( result != 0 ) {
        // process error code and call _callback async
        return false;
    }
    
    LOCK_GUARD(m_PendingMountRequestsLock) {
        m_PendingMountRequests.emplace_back( request_id, move(_callback) );
    }
    
    return true;
    
//    mutable mutex                                   m_PendingMountRequestsLock;
//    vector< pair<void *, MountShareCallback> >      m_PendingMountRequests;

    


//   NetFSMountURLSync((__bridge CFURLRef)[NSURL URLWithString:@"smb://192.168.2.198/Users"], // URL to mount, e.g. nfs://server/path
////    NetFSMountURLSync((__bridge CFURLRef)[NSURL URLWithString:@"smb://192.168.2.198/Users"], // URL to mount, e.g. nfs://server/path
//                      (__bridge CFURLRef)[NSURL URLWithString:@"/Users/migun/2"], // Path for the mountpoint
//                      CFSTR("music"),			// Auth user name (overrides URL)
//                      CFSTR("music"), 			// Auth password (overrides URL)
//                      (__bridge  CFMutableDictionaryRef)open_options,	// Options for session open (see below)
//                      nullptr,	// Options for mounting (see below)
//                      &mounts);		// Array of mountpoints


    
}

bool NetworkConnectionsManager::MountShareAsync(
    const Connection &_conn,
    function<void(const string&_mounted_path, const string&_error)> _callback,
    bool _allow_password_ui)
{
    if( !_conn.IsType<LANShare>() )
        return false;
    
    auto conn = _conn;
    auto &share = conn.Get<LANShare>();
    
    
    string passwd;
    bool shoud_save_passwd = false;
    if( !GetPassword(conn, passwd) ) {
        if( !_allow_password_ui || !AskForPassword(conn, passwd) )
            return false;
        shoud_save_passwd = true;
    }
    
    /// ....
    
    return false;
    
}
