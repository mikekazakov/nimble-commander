// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConfigBackedNetworkConnectionsManager.h"
#include <dirent.h>
#include <NetFS/NetFS.h>
#include <Base/algo.h>
#include <Utility/KeychainServices.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/NativeFSManager.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>
#include <Config/RapidJSON.h>
#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>
#include <NimbleCommander/Bootstrap/NCE.h>
#include <Base/spinlock.h>
#include <Base/dispatch_cpp.h>

#include <algorithm>

using namespace nc;
using namespace std::literals;
using nc::panel::NetworkConnectionsManager;

static const auto g_ConnectionsKey = "connections";
static const auto g_MRUKey = "mostRecentlyUsed";

static void SortByMRU(std::vector<NetworkConnectionsManager::Connection> &_values, const std::vector<base::UUID> &_mru)
{
    std::vector<std::pair<NetworkConnectionsManager::Connection, decltype(begin(_mru))>> v;
    for( auto &i : _values ) {
        auto it = std::ranges::find(_mru, i.Uuid());
        v.emplace_back(std::move(i), it);
    }

    std::ranges::sort(v, [](auto &_1st, auto &_2nd) { return _1st.second < _2nd.second; });

    for( size_t i = 0, e = v.size(); i != e; ++i )
        _values[i] = std::move(v[i].first);
}

static config::Value FillBasicConnectionInfoInJSONObject(const char *_type,
                                                         const NetworkConnectionsManager::BaseConnection &_bc)
{
    auto &alloc = config::g_CrtAllocator;
    config::Value cv(rapidjson::kObjectType);

    cv.AddMember("type", config::Value(_type, alloc), alloc);
    cv.AddMember("title", config::Value(_bc.title, alloc), alloc);
    cv.AddMember("uuid", config::Value(_bc.uuid.ToString(), alloc), alloc);
    return cv;
}

static config::Value ConnectionToJSONObject(NetworkConnectionsManager::Connection _c)
{
    auto &alloc = config::g_CrtAllocator;
    using value = config::Value;

    if( _c.IsType<NetworkConnectionsManager::FTP>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::FTP>();

        auto o = FillBasicConnectionInfoInJSONObject("ftp", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("path", value(c.path.c_str(), alloc), alloc);
        o.AddMember("port", value(static_cast<int>(c.port)), alloc);
        o.AddMember("active", value(c.active), alloc);
        return o;
    }
    if( _c.IsType<NetworkConnectionsManager::SFTP>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::SFTP>();
        auto o = FillBasicConnectionInfoInJSONObject("sftp", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("keypath", value(c.keypath.c_str(), alloc), alloc);
        o.AddMember("port", value(static_cast<int>(c.port)), alloc);
        return o;
    }
    if( _c.IsType<NetworkConnectionsManager::LANShare>() ) {
        auto &c = _c.Get<NetworkConnectionsManager::LANShare>();
        auto o = FillBasicConnectionInfoInJSONObject("lanshare", c);
        o.AddMember("user", value(c.user.c_str(), alloc), alloc);
        o.AddMember("host", value(c.host.c_str(), alloc), alloc);
        o.AddMember("share", value(c.share.c_str(), alloc), alloc);
        o.AddMember("mountpoint", value(c.mountpoint.c_str(), alloc), alloc);
        o.AddMember("proto", value(static_cast<int>(c.proto)), alloc);
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

    return value(rapidjson::kNullType);
}

static std::optional<NetworkConnectionsManager::Connection> JSONObjectToConnection(const config::Value &_object)
{
    using namespace rapidjson;
    auto has_string = [&](const char *k) {
        if( const auto i = _object.FindMember(k); i != _object.MemberEnd() )
            return i->value.GetType() == kStringType;
        return false;
    };
    auto has_number = [&](const char *k) {
        if( const auto i = _object.FindMember(k); i != _object.MemberEnd() )
            return i->value.GetType() == kNumberType;
        return false;
    };
    auto has_bool = [&](const char *k) {
        if( const auto i = _object.FindMember(k); i != _object.MemberEnd() )
            return i->value.GetType() == kFalseType || i->value.GetType() == kTrueType;
        return false;
    };

    if( _object.GetType() != kObjectType )
        return std::nullopt;

    if( !has_string("type") || !has_string("title") || !has_string("uuid") )
        return std::nullopt;

    const auto uuid = base::UUID::FromString(_object["uuid"].GetString());
    if( !uuid )
        return std::nullopt;

    const std::string type = _object["type"].GetString();
    if( type == "ftp" ) {
        if( !has_string("user") || !has_string("host") || !has_string("path") || !has_number("port") )
            return std::nullopt;

        NetworkConnectionsManager::FTP c;
        c.uuid = *uuid;
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.path = _object["path"].GetString();
        c.port = _object["port"].GetInt();
        c.active = has_bool("active") ? _object["active"].GetBool() : false;

        return NetworkConnectionsManager::Connection(std::move(c));
    }
    else if( type == "sftp" ) {
        if( !has_string("user") || !has_string("host") || !has_string("keypath") || !has_number("port") )
            return std::nullopt;

        NetworkConnectionsManager::SFTP c;
        c.uuid = *uuid;
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.keypath = _object["keypath"].GetString();
        c.port = _object["port"].GetInt();

        return NetworkConnectionsManager::Connection(std::move(c));
    }
    else if( type == "lanshare" ) {
        if( !has_string("user") || !has_string("host") || !has_string("share") || !has_string("mountpoint") ||
            !has_number("proto") )
            return std::nullopt;

        NetworkConnectionsManager::LANShare c;
        c.uuid = *uuid;
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.share = _object["share"].GetString();
        c.mountpoint = _object["mountpoint"].GetString();
        c.proto = static_cast<NetworkConnectionsManager::LANShare::Protocol>(_object["proto"].GetInt());

        return NetworkConnectionsManager::Connection(std::move(c));
    }
    else if( type == "dropbox" ) {
        if( !has_string("account") )
            return std::nullopt;

        NetworkConnectionsManager::Dropbox c;
        c.uuid = *uuid;
        c.title = _object["title"].GetString();
        c.account = _object["account"].GetString();

        return NetworkConnectionsManager::Connection(std::move(c));
    }
    else if( type == "webdav" ) {
        if( !has_string("user") || !has_string("host") || !has_string("path") || !has_number("port") ||
            !has_bool("https") )
            return std::nullopt;

        NetworkConnectionsManager::WebDAV c;
        c.uuid = *uuid;
        c.title = _object["title"].GetString();
        c.user = _object["user"].GetString();
        c.host = _object["host"].GetString();
        c.path = _object["path"].GetString();
        c.https = _object["https"].GetBool();
        c.port = _object["port"].GetInt();

        return NetworkConnectionsManager::Connection(std::move(c));
    }

    return std::nullopt;
}

static const std::string &PrefixForShareProtocol(NetworkConnectionsManager::LANShare::Protocol p)
{
    [[clang::no_destroy]] static const auto smb = "smb"s;
    [[clang::no_destroy]] static const auto afp = "afp"s;
    [[clang::no_destroy]] static const auto nfs = "nfs"s;
    [[clang::no_destroy]] static const auto unknown = ""s;
    if( p == NetworkConnectionsManager::LANShare::Protocol::SMB )
        return smb;
    if( p == NetworkConnectionsManager::LANShare::Protocol::AFP )
        return afp;
    if( p == NetworkConnectionsManager::LANShare::Protocol::NFS )
        return nfs;
    return unknown;
}

static std::string KeychainWhereFromConnection(const NetworkConnectionsManager::Connection &_c)
{
    if( auto c = _c.Cast<NetworkConnectionsManager::FTP>() )
        return "ftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::SFTP>() )
        return "sftp://" + c->host;
    if( auto c = _c.Cast<NetworkConnectionsManager::LANShare>() )
        return PrefixForShareProtocol(c->proto) + "://" + (c->user.empty() ? c->user + "@" : "") + c->host + "/" +
               c->share;
    if( auto c = _c.Cast<NetworkConnectionsManager::Dropbox>() )
        return "dropbox://"s + c->account;
    if( auto c = _c.Cast<NetworkConnectionsManager::WebDAV>() )
        return (c->https ? "https://" : "http://") + c->host + (c->path.empty() ? "" : "/" + c->path);
    return "";
}

static std::string KeychainAccountFromConnection(const NetworkConnectionsManager::Connection &_c)
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

ConfigBackedNetworkConnectionsManager::ConfigBackedNetworkConnectionsManager(
    nc::config::Config &_config,
    nc::utility::NativeFSManager &_native_fs_man)
    : m_Config(_config), m_NativeFSManager(_native_fs_man), m_IsWritingConfig(false)
{
    // Load current configuration
    Load();

    // Wire up on-the-fly loading of externally changed config
    m_Config.ObserveMany(
        m_ConfigObservations,
        [this] {
            if( !m_IsWritingConfig )
                Load();
        },
        std::initializer_list<const char *>{g_ConnectionsKey, g_MRUKey});
}

ConfigBackedNetworkConnectionsManager::~ConfigBackedNetworkConnectionsManager() = default;

void ConfigBackedNetworkConnectionsManager::InsertConnection(const NetworkConnectionsManager::Connection &_conn)
{
    {
        auto lock = std::lock_guard{m_Lock};
        auto t = std::ranges::find_if(m_Connections, [&](auto &_c) { return _c.Uuid() == _conn.Uuid(); });
        if( t != end(m_Connections) )
            *t = _conn;
        else
            m_Connections.emplace_back(_conn);
    }
    dispatch_to_background([this] { Save(); });
}

void ConfigBackedNetworkConnectionsManager::RemoveConnection(const Connection &_connection)
{
    {
        auto lock = std::lock_guard{m_Lock};
        auto t = std::ranges::find_if(m_Connections, [&](auto &_c) { return _c.Uuid() == _connection.Uuid(); });
        if( t != end(m_Connections) )
            m_Connections.erase(t);

        auto i = std::ranges::find_if(m_MRU, [&](auto &_c) { return _c == _connection.Uuid(); });
        if( i != end(m_MRU) )
            m_MRU.erase(i);
    }
    dispatch_to_background([this] { Save(); });
}

std::optional<NetworkConnectionsManager::Connection>
ConfigBackedNetworkConnectionsManager::ConnectionByUUID(const base::UUID &_uuid) const
{
    const std::lock_guard<std::mutex> lock(m_Lock);
    auto t = std::ranges::find_if(m_Connections, [&](auto &_c) { return _c.Uuid() == _uuid; });
    if( t != end(m_Connections) )
        return *t;
    return std::nullopt;
}

void ConfigBackedNetworkConnectionsManager::Save()
{
    using Value = config::Value;
    auto &allocator = config::g_CrtAllocator;
    Value connections(rapidjson::kArrayType);
    Value mru(rapidjson::kArrayType);
    {
        auto lock = std::lock_guard{m_Lock};
        for( auto &c : m_Connections ) {
            auto o = ConnectionToJSONObject(c);
            if( o.GetType() != rapidjson::kNullType )
                connections.PushBack(std::move(o), allocator);
        }
        for( auto &u : m_MRU )
            mru.PushBack(Value(u.ToString(), allocator), allocator);
    }

    m_IsWritingConfig = true;
    auto clear = at_scope_end([&] { m_IsWritingConfig = false; });

    m_Config.Set(g_ConnectionsKey, connections);
    m_Config.Set(g_MRUKey, mru);
}

void ConfigBackedNetworkConnectionsManager::Load()
{
    using namespace rapidjson;
    auto lock = std::lock_guard{m_Lock};
    m_Connections.clear();
    m_MRU.clear();

    auto connections = m_Config.Get(g_ConnectionsKey);
    if( connections.GetType() == kArrayType )
        for( auto i = connections.Begin(), e = connections.End(); i != e; ++i )
            if( auto c = JSONObjectToConnection(*i) )
                m_Connections.emplace_back(*c);

    auto mru = m_Config.Get(g_MRUKey);
    if( mru.GetType() == kArrayType )
        for( auto i = mru.Begin(), e = mru.End(); i != e; ++i )
            if( i->GetType() == kStringType && base::UUID::FromString(i->GetString()) )
                m_MRU.emplace_back(*base::UUID::FromString(i->GetString()));
}

void ConfigBackedNetworkConnectionsManager::ReportUsage(const Connection &_connection)
{
    {
        auto lock = std::lock_guard{m_Lock};
        auto it = std::ranges::find_if(m_MRU, [&](auto &i) { return i == _connection.Uuid(); });
        if( it != end(m_MRU) )
            rotate(begin(m_MRU), it, it + 1);
        else
            m_MRU.insert(begin(m_MRU), _connection.Uuid());
    }
    dispatch_to_background([this] { Save(); });
}

std::vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::FTPConnectionsByMRU() const
{
    std::vector<Connection> c;
    auto lock = std::lock_guard{m_Lock};
    for( auto &i : m_Connections )
        if( i.IsType<FTP>() )
            c.emplace_back(i);
    SortByMRU(c, m_MRU);
    return c;
}

std::vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::SFTPConnectionsByMRU() const
{
    std::vector<Connection> c;
    auto lock = std::lock_guard{m_Lock};
    for( auto &i : m_Connections )
        if( i.IsType<SFTP>() )
            c.emplace_back(i);
    SortByMRU(c, m_MRU);
    return c;
}

std::vector<NetworkConnectionsManager::Connection>
ConfigBackedNetworkConnectionsManager::LANShareConnectionsByMRU() const
{
    std::vector<Connection> c;
    {
        auto lock = std::lock_guard{m_Lock};
        for( auto &i : m_Connections )
            if( i.IsType<LANShare>() )
                c.emplace_back(i);
        SortByMRU(c, m_MRU);
    }
    return c;
}

std::vector<NetworkConnectionsManager::Connection> ConfigBackedNetworkConnectionsManager::AllConnectionsByMRU() const
{
    std::vector<Connection> c;
    {
        auto lock = std::lock_guard{m_Lock};
        c = m_Connections;
        SortByMRU(c, m_MRU);
    }
    return c;
}

bool ConfigBackedNetworkConnectionsManager::SetPassword(const Connection &_conn, const std::string &_password)
{
    return KeychainServices::SetPassword(
        KeychainWhereFromConnection(_conn), KeychainAccountFromConnection(_conn), _password);
}

bool ConfigBackedNetworkConnectionsManager::GetPassword(const Connection &_conn, std::string &_password)
{
    return KeychainServices::GetPassword(
        KeychainWhereFromConnection(_conn), KeychainAccountFromConnection(_conn), _password);
}

bool ConfigBackedNetworkConnectionsManager::AskForPassword(const Connection &_conn, std::string &_password)
{
    return RunAskForPasswordModalWindow(TitleForConnection(_conn), _password);
}

std::optional<NetworkConnectionsManager::Connection>
ConfigBackedNetworkConnectionsManager::ConnectionForVFS(const VFSHost &_vfs) const
{
    std::function<bool(const Connection &)> pred;

    if( auto ftp = dynamic_cast<const vfs::FTPHost *>(&_vfs) )
        pred = [ftp](const Connection &i) {
            if( auto p = i.Cast<FTP>() )
                return p->host == ftp->ServerUrl() && p->user == ftp->User() && p->port == ftp->Port() &&
                       p->active == ftp->Active();
            return false;
        };
    else if( auto sftp = dynamic_cast<const vfs::SFTPHost *>(&_vfs) )
        pred = [sftp](const Connection &i) {
            if( auto p = i.Cast<SFTP>() )
                return p->host == sftp->ServerUrl() && p->user == sftp->User() && p->keypath == sftp->Keypath() &&
                       p->port == sftp->Port();
            return false;
        };
    else if( auto dropbox = dynamic_cast<const vfs::DropboxHost *>(&_vfs) )
        pred = [dropbox](const Connection &i) {
            if( auto p = i.Cast<Dropbox>() )
                return p->account == dropbox->Account();
            return false;
        };
    else if( auto webdav = dynamic_cast<const vfs::WebDAVHost *>(&_vfs) )
        pred = [webdav](const Connection &i) {
            if( auto p = i.Cast<WebDAV>() )
                return p->host == webdav->Host() && p->path == webdav->Path() && p->user == webdav->Username();
            return false;
        };

    if( !pred )
        return std::nullopt;

    auto lock = std::lock_guard{m_Lock};
    const auto it = std::ranges::find_if(m_Connections, pred);
    if( it != end(m_Connections) )
        return *it;

    return std::nullopt;
}

VFSHostPtr ConfigBackedNetworkConnectionsManager::SpawnHostFromConnection(const Connection &_connection,
                                                                          bool _allow_password_ui)
{
    std::string passwd;
    bool shoud_save_passwd = false;
    if( !GetPassword(_connection, passwd) ) {
        if( !_allow_password_ui || !AskForPassword(_connection, passwd) )
            return nullptr;
        shoud_save_passwd = true;
    }

    VFSHostPtr host;
    if( auto ftp = _connection.Cast<FTP>() )
        host = std::make_shared<vfs::FTPHost>(ftp->host, ftp->user, passwd, ftp->path, ftp->port, ftp->active);
    else if( auto sftp = _connection.Cast<SFTP>() )
        host = std::make_shared<vfs::SFTPHost>(sftp->host, sftp->user, passwd, sftp->keypath, sftp->port);
    else if( auto dropbox = _connection.Cast<Dropbox>() ) {
        vfs::DropboxHost::Params params;
        params.account = dropbox->account;
        params.access_token = passwd;
        params.client_id = NCE(env::dropbox_client_id);
        params.client_secret = NCE(env::dropbox_client_secret);
        host = std::make_shared<vfs::DropboxHost>(params);
    }
    else if( auto w = _connection.Cast<WebDAV>() )
        host = std::make_shared<vfs::WebDAVHost>(w->host, w->user, passwd, w->path, w->https, w->port);

    if( host ) {
        ReportUsage(_connection);
        if( shoud_save_passwd )
            SetPassword(_connection, passwd);
    }
    return host;
}

static std::string NetFSErrorString(int _code)
{
    if( _code > 0 ) {
        NSError *const err = [NSError errorWithDomain:NSPOSIXErrorDomain code:_code userInfo:nil];
        if( err && err.localizedFailureReason.UTF8String )
            return err.localizedFailureReason.UTF8String;
        else
            return "Unknown error";
    }
    else if( _code < 0 ) {
        NSError *const err = [NSError errorWithDomain:NSOSStatusErrorDomain code:_code userInfo:nil];
        if( err && err.localizedFailureReason.UTF8String )
            return err.localizedFailureReason.UTF8String;
        else
            return "Unknown error";
    }
    return "Unknown error";
}

void ConfigBackedNetworkConnectionsManager::NetFSCallback(int _status, void *_requestID, CFArrayRef _mountpoints)
{
    std::function<void(const std::string &_mounted_path, const std::string &_error)> cb;
    {
        auto lock = std::lock_guard{m_PendingMountRequestsLock};
        auto i = std::ranges::find_if(m_PendingMountRequests, [=](auto &_v) { return _v.first == _requestID; });
        if( i != std::end(m_PendingMountRequests) ) {
            cb = std::move(i->second);
            m_PendingMountRequests.erase(i);
        }
    }

    if( cb ) {
        // _mountpoints can contain a valid mounted path even if _status is not equal to zero
        if( _mountpoints != nullptr && CFArrayGetCount(_mountpoints) != 0 )
            if( auto str = objc_cast<NSString>(((__bridge NSArray *)_mountpoints).firstObject) ) {
                const std::string path = str.fileSystemRepresentationSafe;
                if( !path.empty() ) {
                    cb(path, "");
                    return;
                }
            }
        cb("", NetFSErrorString(_status));
    }
}

static NSURL *CookURLForLANShare(const NetworkConnectionsManager::LANShare &_share)
{
    const auto url_string = PrefixForShareProtocol(_share.proto) + "://" + _share.host + "/" + _share.share;
    const auto cocoa_url_string = [NSString stringWithUTF8StdString:url_string];
    if( !cocoa_url_string )
        return nil;

    return [NSURL URLWithString:cocoa_url_string];
}

static NSURL *CookMountPointForLANShare(const NetworkConnectionsManager::LANShare &_share)
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
static bool IsEmptyDirectory(const std::string &_path)
{
    if( DIR *dir = opendir(_path.c_str()) ) {
        int n = 0;
        while( readdir(dir) != nullptr )
            if( ++n > 2 )
                break;
        closedir(dir);
        return n <= 2;
    }
    return false;
}

static bool
TearDownSMBOrAFPMountName(const std::string &_name, std::string &_user, std::string &_host, std::string &_share)
{
    auto url_string = [NSString stringWithUTF8StdString:_name];
    if( !url_string )
        return false;

    NSURL *const url = [NSURL URLWithString:url_string];
    if( !url )
        return false;

    if( !url.host || !url.path )
        return false;

    _host = url.host.UTF8String;  // 192.168.2.5
    _share = url.path.UTF8String; // i.e. /iTunesMusic
    if( !_share.empty() )
        _share.erase(begin(_share)); // i.e. iTunesMusic

    if( url.user )
        _user = url.user.UTF8String;
    else
        _user = "";

    return true;
}

static bool TearDownNFSMountName(const std::string &_name, std::string &_host, std::string &_share)
{
    [[clang::no_destroy]] static const auto delimiter = ":/"s;
    auto pos = _name.find(delimiter);
    if( pos == std::string::npos )
        return false;
    _host = _name.substr(0, pos);
    _share = _name.substr(pos + delimiter.size());
    return true;
}

static std::vector<std::shared_ptr<const nc::utility::NativeFileSystemInfo>>
GetMountedRemoteFilesystems(nc::utility::NativeFSManager &_native_fs_man)
{
    [[clang::no_destroy]] static const auto smb = "smbfs"s;
    [[clang::no_destroy]] static const auto afp = "afpfs"s;
    [[clang::no_destroy]] static const auto nfs = "nfs"s;
    std::vector<std::shared_ptr<const nc::utility::NativeFileSystemInfo>> remotes;

    for( const auto &v : _native_fs_man.Volumes() ) {
        const auto &volume = *v;

        // basic discarding check on volume
        if( volume.mount_flags.internal || volume.mount_flags.local )
            continue;

        // treat only these filesystems as remote
        if( volume.fs_type_name == smb || volume.fs_type_name == afp || volume.fs_type_name == nfs ) {
            remotes.emplace_back(v);
        }
    }

    return remotes;
}

static bool MatchVolumeWithShare(const nc::utility::NativeFileSystemInfo &_volume,
                                 const NetworkConnectionsManager::LANShare &_share)
{
    [[clang::no_destroy]] static const auto smb = "smbfs"s;
    [[clang::no_destroy]] static const auto afp = "afpfs"s;
    [[clang::no_destroy]] static const auto nfs = "nfs"s;
    using protocols = NetworkConnectionsManager::LANShare::Protocol;
    if( (_share.proto == protocols::SMB && _volume.fs_type_name == smb) ||
        (_share.proto == protocols::AFP && _volume.fs_type_name == afp) ) {
        std::string user;
        std::string host;
        std::string share;
        if( TearDownSMBOrAFPMountName(_volume.mounted_from_name, user, host, share) ) {
            auto same_host = strcasecmp(host.c_str(), _share.host.c_str()) == 0;
            auto same_share = strcasecmp(share.c_str(), _share.share.c_str()) == 0;
            auto same_user = (strcasecmp(user.c_str(), _share.user.c_str()) == 0) ||
                             (_share.user.empty() && user == "GUEST") || (_share.user.empty() && user == "guest");
            return same_host && same_share && same_user;
        }
    }
    else if( _share.proto == protocols::NFS && _volume.fs_type_name == nfs ) {
        std::string host;
        std::string share;
        if( TearDownNFSMountName(_volume.mounted_from_name, host, share) ) {
            auto same_host = strcasecmp(host.c_str(), _share.host.c_str()) == 0;
            auto same_share = strcasecmp(share.c_str(), _share.share.c_str()) == 0;
            return same_host && same_share;
        }
    }
    return false;
}

static std::shared_ptr<const nc::utility::NativeFileSystemInfo>
FindExistingMountedShare(const NetworkConnectionsManager::LANShare &_share,
                         nc::utility::NativeFSManager &_native_fs_man)
{
    for( auto &v : GetMountedRemoteFilesystems(_native_fs_man) )
        if( MatchVolumeWithShare(*v, _share) )
            return v;
    return nullptr;
}

bool ConfigBackedNetworkConnectionsManager::MountShareAsync(
    const Connection &_conn,
    const std::string &_password,
    std::function<void(const std::string &_mounted_path, const std::string &_error)> _callback)
{
    if( !_conn.IsType<LANShare>() )
        return false;

    const auto &conn = _conn;
    const auto &share = conn.Get<LANShare>();

    if( const auto v = FindExistingMountedShare(share, m_NativeFSManager) ) {
        // we already have this share mounted - just return it.
        // mount path may be different although
        dispatch_to_main_queue([v, _callback] { _callback(v->mounted_at_path, ""); });
        return true;
    }

    auto url = CookURLForLANShare(share);
    auto mountpoint = CookMountPointForLANShare(share);
    auto username = share.user.empty() ? nil : [NSString stringWithUTF8StdString:share.user];
    auto passwd = _password.empty() ? nil : [NSString stringWithUTF8StdString:_password];
    auto open_options = static_cast<NSMutableDictionary *>([@{@"UIOption": @"NoUI"} mutableCopy]);
    auto mount_options = (!mountpoint || !IsEmptyDirectory(share.mountpoint))
                             ? nil
                             : static_cast<NSMutableDictionary *>(
                                   [@{@"MountAtMountDir": @true} mutableCopy]);

    auto callback = [this](int status, AsyncRequestID requestID, CFArrayRef mountpoints) {
        NetFSCallback(status, requestID, mountpoints);
    };

    AsyncRequestID request_id;
    const int result = NetFSMountURLAsync((__bridge CFURLRef)url,
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
        dispatch_to_main_queue([error, _callback] { _callback("", error); });
        return false;
    }

    auto lock = std::lock_guard{m_PendingMountRequestsLock};
    m_PendingMountRequests.emplace_back(request_id, std::move(_callback));
    return true;
}
