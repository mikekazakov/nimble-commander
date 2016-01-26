#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>

#include <Habanero/spinlock.h>
#include "vfs/vfs_net_ftp.h"
#include "vfs/vfs_net_sftp.h"
#include "AppDelegate.h"
#include "NetworkConnectionsManager.h"
#include "KeychainServices.h"
#include "Common.h"
#include "AskForPasswordWindowController.h"

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

static string KeychainWhereFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTPConnection>() )
        return "ftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTPConnection>() )
        return "sftp://" + c->host;
    return "";
}

static string KeychainAccountFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTPConnection>() )
        return c->user;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTPConnection>() )
        return c->user;
    return "";
}

static string ResourceNameForUIFromConnection( const NetworkConnectionsManager::Connection& _c )
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTPConnection>() )
        return "ftp://" + (c->user.empty() ? ""s : c->user + "@") + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTPConnection>() )
        return "sftp://" + c->user + "@" + c->host;
    return "";
}

NetworkConnectionsManager::NetworkConnectionsManager():
    m_Config("", AppDelegate.me.configDirectory + g_ConfigFilename)
{
    // Load current configuration
    Load();
    
    // Wire up on-the-fly loading of externally changed config
    m_Config.ObserveMany(m_ConfigObservations, [=]{ Load(); },
                         initializer_list<const char*>{g_ConnectionsKey, g_MRUKey}
                         );

    // Wire up notification about application shutdown
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
                                                    m_Config.NotifyAboutShutdown();
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

string NetworkConnectionsManager::TitleForConnection(const Connection &_conn) const
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
    
    return "";
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

bool NetworkConnectionsManager::GetPassword(const Connection &_conn, string& _password, bool _allow_interactive_ui)
{
    if( KeychainServices::Instance().GetPassword(KeychainWhereFromConnection(_conn), KeychainAccountFromConnection(_conn), _password) )
        return true;
    
    if( _allow_interactive_ui )
        if( RunAskForPasswordModalWindow( ResourceNameForUIFromConnection(_conn), _password) ) {
            SetPassword(_conn, _password);
            return true;
        }
    
    return false;
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

VFSHostPtr NetworkConnectionsManager::SpawnHostFromConnection(const Connection &_connection)
{
    string passwd;
    if( !GetPassword(_connection, passwd) )
        return nullptr;
    
    try {
        VFSHostPtr host;
        if( auto *ftp = _connection.Cast<FTPConnection>() )
            host = make_shared<VFSNetFTPHost>( ftp->host, ftp->user, passwd, ftp->path, ftp->port );
        if( auto *sftp = _connection.Cast<SFTPConnection>() )
            host = make_shared<VFSNetSFTPHost>( sftp->host, sftp->user, passwd, sftp->keypath, sftp->port );
        
        if( host ) {
            ReportUsage(_connection);
            return host;
        }
    }
    catch (VFSErrorException &ee) {
    }
    return nullptr;
}
