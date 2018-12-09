// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#include <boost/uuid/uuid_io.hpp>
#include <boost/uuid/string_generator.hpp>
#pragma clang diagnostic pop
#include <boost/container/static_vector.hpp>
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include <VFS/ArcUnRAR.h>
#include <VFS/PS.h>
#include <VFS/XAttr.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include <Config/RapidJSON.h>
#include "PanelDataPersistency.h"

// THIS IS TEMPORARY!!!
#include <NimbleCommander/Bootstrap/AppDelegateCPP.h>
static NetworkConnectionsManager &ConnectionsManager()
{
    return *nc::AppDelegate::NetworkConnectionsManager();
}

namespace nc::panel {
    
using nc::config::Value; 

//type: "type", // VFSNativeHost::Tag, VFSPSHost::Tag, VFSArchiveHost::Tag, VFSArchiveUnRARHost::Tag, VFSXAttrHost::Tag, "network"
// perhaps "archive" in the future, when more of them will come and some dedicated "ArchiveManager" will appear
//junction: "path"

static const auto g_StackHostsKey = "hosts_v1";
static const auto g_StackPathKey = "path";
static const auto g_HostInfoTypeKey = "type";
static const auto g_HostInfoTypeNetworkValue = "network";
static const auto g_HostInfoJunctionKey = "junction";
static const auto g_HostInfoUuidKey = "uuid";
//
//{
//hosts: [...]
//path: "/erere/rere/trtr"
//}


namespace {

struct Native
{
    /* native hosts does not need any context information */
};

struct PSFS
{
    /* native hosts does not need any context information */
};

struct XAttr
{
    std::string junction;
};

struct Network
{
    boost::uuids::uuid connection;
};

struct ArcLA
{
    std::string junction;
};

struct ArcUnRAR
{
    std::string junction;
};

};

PanelDataPersisency::PanelDataPersisency( const NetworkConnectionsManager &_conn_manager ):
    m_ConnectionsManager(_conn_manager)
{
}

bool PersistentLocation::is_native() const noexcept
{
    if( hosts.empty() )
        return true;
    
    if( hosts.size() == 1 && std::any_cast<Native>(&hosts.front()) != nullptr )
        return true;
        
    return false;
}

bool PersistentLocation::is_network() const noexcept
{
    return !hosts.empty() && std::any_cast<Network>(&hosts.front());
}

static nc::config::Value EncodeAny( const std::any& _host );

static bool IsNetworkVFS( const VFSHost& _host )
{
    const auto tag = _host.Tag();
    return tag == vfs::FTPHost::UniqueTag ||
           tag == vfs::SFTPHost::UniqueTag ||
           tag == vfs::DropboxHost::UniqueTag ||
           tag == vfs::WebDAVHost::UniqueTag;
}

static std::any EncodeState( const VFSHost& _host )
{
    auto tag = _host.Tag();
    if( tag == VFSNativeHost::UniqueTag ) {
        return Native{};
    }
    else if( tag == vfs::PSHost::UniqueTag ) {
        return PSFS{};
    }
    else if( tag == vfs::XAttrHost::UniqueTag ) {
        return XAttr{ _host.JunctionPath() };
    }
    else if( IsNetworkVFS(_host) ) {
        if( auto conn = ConnectionsManager().ConnectionForVFS(_host) )
            return Network{ conn->Uuid() };
    }
    else if( tag == vfs::ArchiveHost::UniqueTag ) {
        return ArcLA{ _host.JunctionPath() };
    }
    else if( tag == vfs::UnRARHost::UniqueTag ) {
        return ArcUnRAR{ _host.JunctionPath() };
    }
    return {};
}

std::optional<PersistentLocation> PanelDataPersisency::
    EncodeLocation( const VFSHost &_vfs, const std::string &_path )
{
    PersistentLocation location;

    // in case of native vfs we simply omit mentioning is - simply path is enough
    if( !_vfs.IsNativeFS() ) {
        boost::container::static_vector<const VFSHost*, 32> hosts;
        auto host_rec = &_vfs;
        while( host_rec ) {
            hosts.emplace_back( host_rec );
            host_rec = host_rec->Parent().get();
        }
        
        reverse( begin(hosts), end(hosts) );

        for( auto h: hosts ) {
            auto encoded = EncodeState(*h);
            if( encoded.has_value() )
                location.hosts.emplace_back( move(encoded) );
            else
                return std::nullopt;
        }
    }
    location.path = _path;
    if( location.path.empty() || location.path.back() != '/' )
        location.path.push_back('/');
    
    return location;
}

Value PanelDataPersisency::EncodeVFSPath( const VFSListing &_listing )
{
    if( !_listing.IsUniform() )
        return nc::config::Value{rapidjson::kNullType};

    return EncodeVFSPath( *_listing.Host(), _listing.Directory() );
}

Value PanelDataPersisency::EncodeVFSPath( const VFSHost &_vfs, const std::string &_path )
{
    std::vector<const VFSHost*> hosts;
    auto host_rec = &_vfs;
    while( host_rec ) {
        hosts.emplace_back( host_rec );
        host_rec = host_rec->Parent().get();
    }
    
    reverse( begin(hosts), end(hosts) );
    
    Value json(rapidjson::kObjectType);
    Value json_hosts(rapidjson::kArrayType);
    for( auto h: hosts )
        if( auto v = EncodeVFSHostInfo(*h); v.GetType() != rapidjson::kNullType )
            json_hosts.PushBack( std::move(v), nc::config::g_CrtAllocator );
        else
            return Value{rapidjson::kNullType};
    if( !json_hosts.Empty() )
        json.AddMember(Value(g_StackHostsKey, nc::config::g_CrtAllocator),
                       std::move(json_hosts),
                       nc::config::g_CrtAllocator);
    
    json.AddMember(Value(g_StackPathKey, nc::config::g_CrtAllocator),
                   Value(_path.c_str(), nc::config::g_CrtAllocator),
                   nc::config::g_CrtAllocator);
    
    return json;
}

Value PanelDataPersisency::LocationToJSON( const PersistentLocation &_location )
{
    Value json(rapidjson::kObjectType);
    Value json_hosts(rapidjson::kArrayType);
    for( auto &h: _location.hosts )
        if( auto v = EncodeAny(h); v.GetType() != rapidjson::kNullType )
            json_hosts.PushBack( std::move(v), nc::config::g_CrtAllocator );
        else
            return Value{rapidjson::kNullType};
    if( !json_hosts.Empty() )
        json.AddMember(Value(g_StackHostsKey, nc::config::g_CrtAllocator),
                       std::move(json_hosts),
                       nc::config::g_CrtAllocator);
    
    json.AddMember(Value(g_StackPathKey, nc::config::g_CrtAllocator),
                   Value(_location.path, nc::config::g_CrtAllocator),
                   nc::config::g_CrtAllocator);
    
    return json;
}

std::optional<PersistentLocation> PanelDataPersisency::JSONToLocation( const json &_json )
{
    if( !_json.IsObject() || !_json.HasMember(g_StackPathKey) || !_json[g_StackPathKey].IsString() )
        return std::nullopt;

    PersistentLocation result;
    result.path = _json[g_StackPathKey].GetString();
    
    if( !_json.HasMember(g_StackHostsKey) )
        return std::move(result);
    
    if( _json.HasMember(g_StackHostsKey) && _json[g_StackHostsKey].IsArray() ) {
        auto &hosts = _json[g_StackHostsKey];
        for( auto i = hosts.Begin(), e = hosts.End(); i != e; ++i ) {
            auto &h = *i;
            const auto has_string = [&h](const char *_key) { return h.HasMember(_key) && h[_key].IsString(); };
            
            if( !has_string(g_HostInfoTypeKey) )
                return std::nullopt; // invalid data
            const auto tag = std::string_view{ h[g_HostInfoTypeKey].GetString() };
            
            if( tag == VFSNativeHost::UniqueTag ) {
                result.hosts.emplace_back( Native{} );
            }
            else if( tag == vfs::PSHost::UniqueTag ) {
                result.hosts.emplace_back( PSFS{} );
            }
            else if( tag == vfs::XAttrHost::UniqueTag ) {
                if( !has_string(g_HostInfoJunctionKey) )
                    return std::nullopt; // invalid data
                if( result.hosts.size() < 1 )
                    return std::nullopt; // invalid data
                
                result.hosts.emplace_back( XAttr{  h[g_HostInfoJunctionKey].GetString() } );
            }
            else if( tag == g_HostInfoTypeNetworkValue ) {
                if( !has_string(g_HostInfoUuidKey) )
                    return std::nullopt; // invalid data
                
                static const boost::uuids::string_generator uuid_gen{};
                const auto uuid = uuid_gen( h[g_HostInfoUuidKey].GetString() );
                
                result.hosts.emplace_back( Network{ uuid } );
            }
            else if( tag == vfs::ArchiveHost::UniqueTag ) {
                if( !has_string(g_HostInfoJunctionKey) )
                    return std::nullopt; // invalid data
                if( result.hosts.size() < 1 )
                    return std::nullopt; // invalid data
                
                result.hosts.emplace_back( ArcLA{ h[g_HostInfoJunctionKey].GetString() } );
            }
            else if( tag == vfs::UnRARHost::UniqueTag ) {
                if( !has_string(g_HostInfoJunctionKey) )
                    return std::nullopt; // invalid data
                if( result.hosts.size() < 1 || !std::any_cast<Native>(&result.hosts.back()) )
                    return std::nullopt; // invalid data
                
                result.hosts.emplace_back( ArcUnRAR{ h[g_HostInfoJunctionKey].GetString() } );
            }
        }
    }

    return std::move(result);
}

static const char *VFSTagForNetworkConnection( const NetworkConnectionsManager::Connection &_conn )
{
    if( auto ftp = _conn.Cast<NetworkConnectionsManager::FTP>() )
        return vfs::FTPHost::UniqueTag;
    else if( auto sftp =_conn.Cast<NetworkConnectionsManager::SFTP>() )
        return vfs::SFTPHost::UniqueTag;
    else if( auto dropbox = _conn.Cast<NetworkConnectionsManager::Dropbox>() )
        return vfs::DropboxHost::UniqueTag;
    else if( auto webdav = _conn.Cast<NetworkConnectionsManager::WebDAV>() )
        return vfs::WebDAVHost::UniqueTag;
    else
        return "<unknown_vfs>";
}

std::string PanelDataPersisency::MakeFootprintString( const PersistentLocation &_loc )
{
    std::string footprint;
    if( _loc.hosts.empty() ) {
        footprint += VFSNativeHost::UniqueTag;
        footprint += "||";
    }
    for( auto &h: _loc.hosts ) {
        if( auto native = std::any_cast<Native>(&h) ) {
            footprint += VFSNativeHost::UniqueTag;
            footprint += "|";
        }
        else if( auto psfs = std::any_cast<PSFS>(&h) ) {
            footprint += vfs::PSHost::UniqueTag;
            footprint += "|[psfs]:";
        }
        else if( auto xattr = std::any_cast<XAttr>(&h) ) {
            footprint += vfs::XAttrHost::UniqueTag;
            footprint += "|";
            footprint += xattr->junction;
        }
        else if( auto network = std::any_cast<Network>(&h) ) {
            const auto &mgr = ConnectionsManager();
            if( auto conn = mgr.ConnectionByUUID(network->connection) ) {
                footprint += VFSTagForNetworkConnection(*conn);
                footprint += "|";
                footprint += NetworkConnectionsManager::MakeConnectionPath(*conn);
            }
        }
        else if( auto la = std::any_cast<ArcLA>(&h) ) {
            footprint += vfs::ArchiveHost::UniqueTag;
            footprint += "|";
            footprint += la->junction;
        }
        else if( auto rar = std::any_cast<ArcUnRAR>(&h) ) {
            footprint += vfs::UnRARHost::UniqueTag;
            footprint += "|";
            footprint += rar->junction;
        }
        footprint += "|";
    }
    
    footprint += _loc.path;
    return footprint;
}

size_t PanelDataPersisency::MakeFootprintStringHash( const PersistentLocation &_loc )
{
    return std::hash<std::string>()( MakeFootprintString(_loc) );
}

std::string PanelDataPersisency::MakeVerbosePathString( const PersistentLocation &_loc )
{
    std::string verbose;
    for( auto &h: _loc.hosts ) {
        if( auto psfs = std::any_cast<PSFS>(&h) )
            verbose += "[psfs]:";
        else if( auto xattr = std::any_cast<XAttr>(&h) )
            verbose += xattr->junction;
        else if( auto network = std::any_cast<Network>(&h) ) {
            const auto &mgr = ConnectionsManager();
            if( auto conn = mgr.ConnectionByUUID(network->connection) )
                verbose += NetworkConnectionsManager::MakeConnectionPath(*conn);
        }
        else if( auto la = std::any_cast<ArcLA>(&h) )
            verbose += la->junction;
        else if( auto rar = std::any_cast<ArcUnRAR>(&h) )
            verbose += rar->junction;
    }
    
    verbose += _loc.path;
    return verbose;
}

std::string PanelDataPersisency::
    MakeVerbosePathString( const VFSHost &_host, const std::string &_directory )
{
    std::array<const VFSHost*, 32> hosts;
    int hosts_n = 0;

    auto cur = &_host;
    while( cur ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    std::string s;
    while(hosts_n > 0)
        s += hosts[--hosts_n]->Configuration().VerboseJunction();
    s += _directory;
    if(s.back() != '/') s += '/';
    return s;
}

Value PanelDataPersisency::EncodeVFSHostInfo( const VFSHost& _host )
{
    using namespace rapidjson;
    using namespace nc::config;
    auto tag = _host.Tag();
    Value json(rapidjson::kObjectType);
    if( tag == VFSNativeHost::UniqueTag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        return json;
    }
    else if( tag == vfs::PSHost::UniqueTag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        return json;
    }
    else if( tag == vfs::XAttrHost::UniqueTag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        json.AddMember( MakeStandaloneString(g_HostInfoJunctionKey), MakeStandaloneString(_host.JunctionPath()), g_CrtAllocator );
        return json;
    }
    else if( IsNetworkVFS(_host) ) {
        if( auto conn = ConnectionsManager().ConnectionForVFS(_host) )  {
            json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(g_HostInfoTypeNetworkValue), g_CrtAllocator );
            json.AddMember( MakeStandaloneString(g_HostInfoUuidKey), MakeStandaloneString(to_string(conn->Uuid()).c_str()), g_CrtAllocator );
            return json;
        }
    }
    else if( tag == vfs::ArchiveHost::UniqueTag ||
             tag == vfs::UnRARHost::UniqueTag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        json.AddMember( MakeStandaloneString(g_HostInfoJunctionKey), MakeStandaloneString(_host.JunctionPath()), g_CrtAllocator );
        return json;
    }
    return Value{kNullType};
}

static Value EncodeAny( const std::any& _host )
{
    using namespace rapidjson;
    using namespace nc::config;
    Value json(rapidjson::kObjectType);
    if( auto native = std::any_cast<Native>(&_host) ) {
        json.AddMember(MakeStandaloneString(g_HostInfoTypeKey),
                       MakeStandaloneString(VFSNativeHost::UniqueTag),
                       g_CrtAllocator );
        return json;
    }
    else if( auto psfs = std::any_cast<PSFS>(&_host) ) {
        json.AddMember(MakeStandaloneString(g_HostInfoTypeKey),
                       MakeStandaloneString(vfs::PSHost::UniqueTag),
                       g_CrtAllocator );
        return json;
    }
    else if( auto xattr = std::any_cast<XAttr>(&_host) ) {
        json.AddMember(MakeStandaloneString(g_HostInfoTypeKey),
                       MakeStandaloneString(vfs::XAttrHost::UniqueTag),
                       g_CrtAllocator );
        json.AddMember( MakeStandaloneString(g_HostInfoJunctionKey),
                       MakeStandaloneString(xattr->junction),
                       g_CrtAllocator );
        return json;
    }
    else if( auto network = std::any_cast<Network>(&_host) ) {
        json.AddMember(MakeStandaloneString(g_HostInfoTypeKey),
                       MakeStandaloneString(g_HostInfoTypeNetworkValue),
                       g_CrtAllocator );
        json.AddMember(MakeStandaloneString(g_HostInfoUuidKey),
                       MakeStandaloneString(to_string(network->connection)),
                       g_CrtAllocator );
        return json;
    }
    else if( auto la = std::any_cast<ArcLA>(&_host) ) {
        json.AddMember(MakeStandaloneString(g_HostInfoTypeKey),
                       MakeStandaloneString(vfs::ArchiveHost::UniqueTag),
                       g_CrtAllocator );
        json.AddMember(MakeStandaloneString(g_HostInfoJunctionKey),
                       MakeStandaloneString(la->junction),
                       g_CrtAllocator );
        return json;
    }
    else if( auto rar = std::any_cast<ArcUnRAR>(&_host) ) {
        json.AddMember(MakeStandaloneString(g_HostInfoTypeKey),
                       MakeStandaloneString(vfs::UnRARHost::UniqueTag),
                       g_CrtAllocator );
        json.AddMember(MakeStandaloneString(g_HostInfoJunctionKey),
                       MakeStandaloneString(rar->junction),
                       g_CrtAllocator );
        return json;
    }
    
    return Value{kNullType};
}

static bool Fits( VFSHost& _alive, const std::any &_encoded )
{
    const auto tag = _alive.Tag();
    const auto encoded = &_encoded;

    if( tag == VFSNativeHost::UniqueTag ) {
        if( std::any_cast<Native>(encoded) )
            return true;
    }
    else if( tag == vfs::PSHost::UniqueTag ) {
        if( std::any_cast<PSFS>(encoded) )
            return true;
    }
    else if( tag == vfs::XAttrHost::UniqueTag ) {
        if( auto xattr = std::any_cast<XAttr>(encoded) )
            return xattr->junction == _alive.JunctionPath();
    }
    else if( IsNetworkVFS(_alive) ) {
        if( auto network = std::any_cast<Network>(encoded) )
            if( auto conn = ConnectionsManager().ConnectionForVFS( _alive ) )
                return network->connection == conn->Uuid();
    }
    else if( tag == vfs::ArchiveHost::UniqueTag ) {
        if( auto la = std::any_cast<ArcLA>(encoded) )
            return la->junction == _alive.JunctionPath();
    }
    else if( tag == vfs::UnRARHost::UniqueTag ) {
        if( auto unrar = std::any_cast<ArcUnRAR>(encoded) )
            return unrar->junction == _alive.JunctionPath();
    }
    return false;
}

static VFSHostPtr FindFitting(
    const std::vector<std::weak_ptr<VFSHost>> &_hosts,
    const std::any &_encoded,
    const VFSHost *_parent /* may be nullptr */ )
{
    for( auto &weak_host: _hosts )
        if( auto host = weak_host.lock() )
            if( Fits(*host, _encoded) )
                if( host->Parent().get() == _parent ) // comparison of two nullptrs is ok here
                    return host;
    return nullptr;
}

int PanelDataPersisency::CreateVFSFromLocation(const PersistentLocation &_state,
                                               VFSHostPtr &_host,
                                               core::VFSInstanceManager &_inst_mgr)
{
    if( _state.hosts.empty() ) {
        // short path for most common case - native vfs
        _host = VFSNativeHost::SharedHost();
        return 0;
    }

    std::vector<VFSHostPtr> vfs;
    auto alive_hosts = _inst_mgr.AliveHosts(); // make it optional perhaps?
    try {
        for( auto &h: _state.hosts) {
            const VFSHostPtr back = vfs.empty() ? nullptr : vfs.back();

            if( auto exist = FindFitting(alive_hosts, h, back.get() ) ) { // we're lucky!
                vfs.emplace_back( exist );
                continue;
            }
            // no luck - have to build this layer from scratch
            
            if( auto native = std::any_cast<Native>(&h) ) {
                vfs.emplace_back( VFSNativeHost::SharedHost() );
            }
            else if( auto psfs = std::any_cast<PSFS>(&h) ) {
                vfs.emplace_back( vfs::PSHost::GetSharedOrNew() );
            }
            else if( auto xattr = std::any_cast<XAttr>(&h) ) {
                if( vfs.size() < 1 )
                    return VFSError::GenericError; // invalid data
                
                auto xattr_vfs = std::make_shared<vfs::XAttrHost>(xattr->junction.c_str(),
                                                                  vfs.back() );
                vfs.emplace_back( xattr_vfs );
            }
            else if( auto network = std::any_cast<Network>(&h) ) {
                auto &mgr = ConnectionsManager();
                if( auto conn = mgr.ConnectionByUUID(network->connection) ) {
                    if ( auto host = mgr.SpawnHostFromConnection(*conn) )
                        vfs.emplace_back( host );
                    else
                        return VFSError::GenericError; // failed to spawn connection
                }
                else
                    return VFSError::GenericError; // failed to find connection by uuid
            }
            else if( auto la = std::any_cast<ArcLA>(&h) ) {
                if( vfs.size() < 1 )
                    return VFSError::GenericError; // invalid data
                
                auto host = std::make_shared<vfs::ArchiveHost>( la->junction.c_str(), vfs.back() );
                vfs.emplace_back( host );
            }
            else if( auto rar = std::any_cast<ArcUnRAR>(&h) ) {
                if( vfs.size() < 1 || !vfs.back()->IsNativeFS() )
                    return VFSError::GenericError; // invalid data
                
                auto host = std::make_shared<vfs::UnRARHost>( rar->junction.c_str() );
                vfs.emplace_back( host );
            }
        }
    }
    catch(VFSErrorException &ee) {
        return ee.code();
    }
    
    if( !vfs.empty() ) {
        _host = vfs.back();
        return VFSError::Ok;
    }
    else
        return VFSError::GenericError;
}

std::string PanelDataPersisency::GetPathFromState( const Value &_state )
{
    if( _state.IsObject() && _state.HasMember(g_StackPathKey) && _state[g_StackPathKey].IsString() )
        return _state[g_StackPathKey].GetString();
    
    return "";
}

std::optional<NetworkConnectionsManager::Connection> PanelDataPersisency::
    ExtractConnectionFromLocation( const PersistentLocation &_location )
{
    if( _location.hosts.empty() )
        return std::nullopt;
    
    if( auto network = std::any_cast<Network>(&_location.hosts.front()) )
        if( auto conn = m_ConnectionsManager.ConnectionByUUID(network->connection) )
            return conn;
    
    return std::nullopt;
}

}
