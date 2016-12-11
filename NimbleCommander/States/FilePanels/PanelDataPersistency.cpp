#include <boost/uuid/uuid_io.hpp>
#include <boost/uuid/string_generator.hpp>
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include <VFS/ArcUnRAR.h>
#include <VFS/PS.h>
#include <VFS/XAttr.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include "PanelDataPersistency.h"

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


optional<rapidjson::StandaloneValue> PanelDataPersisency::EncodeVFSPath( const VFSListing &_listing )
{
    if( !_listing.IsUniform() )
        return nullopt;
    
    vector<VFSHost*> hosts;
    auto host_rec = _listing.Host().get();
    while( host_rec ) {
        hosts.emplace_back( host_rec );
        host_rec = host_rec->Parent().get();
    }
    
    reverse( begin(hosts), end(hosts) );
    
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    rapidjson::StandaloneValue json_hosts(rapidjson::kArrayType);
    for( auto h: hosts )
        if( auto v = EncodeVFSHostInfo(*h) )
            json_hosts.PushBack( move(*v), rapidjson::g_CrtAllocator );
        else
            return nullopt;
    
    json.AddMember(rapidjson::StandaloneValue(g_StackHostsKey, rapidjson::g_CrtAllocator),
                   move(json_hosts),
                   rapidjson::g_CrtAllocator);
    
    json.AddMember(rapidjson::StandaloneValue(g_StackPathKey, rapidjson::g_CrtAllocator),
                   rapidjson::StandaloneValue(_listing.Directory().c_str(), rapidjson::g_CrtAllocator),
                   rapidjson::g_CrtAllocator);
    
    return move(json);
}

optional<rapidjson::StandaloneValue> PanelDataPersisency::EncodeVFSHostInfo( const VFSHost& _host )
{
    using namespace rapidjson;
    auto tag = _host.FSTag();
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    if( tag == VFSNativeHost::Tag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        return move(json);
    }
    else if( tag == VFSPSHost::Tag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        return move(json);
    }
    else if( tag == VFSXAttrHost::Tag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        json.AddMember( MakeStandaloneString(g_HostInfoJunctionKey), MakeStandaloneString(_host.JunctionPath()), g_CrtAllocator );
        return move(json);
    }
    else if( tag == VFSNetFTPHost::Tag ||
             tag == VFSNetSFTPHost::Tag ) {
        if( auto conn = NetworkConnectionsManager::Instance().ConnectionForVFS(_host) )  {
            json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(g_HostInfoTypeNetworkValue), g_CrtAllocator );
            json.AddMember( MakeStandaloneString(g_HostInfoUuidKey), MakeStandaloneString(to_string(conn->Uuid()).c_str()), g_CrtAllocator );
            return move(json);
        }
    }
    else if( tag == VFSArchiveHost::Tag ||
             tag == VFSArchiveUnRARHost::Tag ) {
        json.AddMember( MakeStandaloneString(g_HostInfoTypeKey), MakeStandaloneString(tag), g_CrtAllocator );
        json.AddMember( MakeStandaloneString(g_HostInfoJunctionKey), MakeStandaloneString(_host.JunctionPath()), g_CrtAllocator );
        return move(json);
    }
    return nullopt;
}

int PanelDataPersisency::CreateVFSFromState( const rapidjson::StandaloneValue &_state, VFSHostPtr &_host )
{
    if( _state.IsObject() && _state.HasMember(g_StackHostsKey) && _state[g_StackHostsKey].IsArray() ) {
        auto &hosts = _state[g_StackHostsKey];
        vector<VFSHostPtr> vfs;
        
        try {
            for( auto i = hosts.Begin(), e = hosts.End(); i != e; ++i ) {
                auto &h = *i;
                const auto has_string = [&h](const char *_key) { return h.HasMember(_key) && h[_key].IsString(); };
                
                if( !has_string(g_HostInfoTypeKey) )
                    return VFSError::GenericError; // invalid data
                const auto tag = string_view{ h[g_HostInfoTypeKey].GetString() };
                
                if( tag == VFSNativeHost::Tag ) {
                    vfs.emplace_back( VFSNativeHost::SharedHost() );
                }
                else if( tag == VFSPSHost::Tag ) {
                    vfs.emplace_back( VFSPSHost::GetSharedOrNew() );
                }
                else if( tag == VFSXAttrHost::Tag ) {
                    if( !has_string(g_HostInfoJunctionKey) )
                        return VFSError::GenericError; // invalid data
                    if( vfs.size() < 1 )
                        return VFSError::GenericError; // invalid data
                    
                    auto xattr_vfs = make_shared<VFSXAttrHost>( h[g_HostInfoJunctionKey].GetString(), vfs.back() );
                    vfs.emplace_back( xattr_vfs );
                }
                else if( tag == g_HostInfoTypeNetworkValue ) {
                    if( !has_string(g_HostInfoUuidKey) )
                        return VFSError::GenericError; // invalid data

                    static const boost::uuids::string_generator uuid_gen{};
                    const auto uuid = uuid_gen( h[g_HostInfoUuidKey].GetString() );
                    if( auto connection = NetworkConnectionsManager::Instance().ConnectionByUUID( uuid ) ) {
                        if ( auto host = NetworkConnectionsManager::Instance().SpawnHostFromConnection(*connection) )
                            vfs.emplace_back( host );
                        else
                            return VFSError::GenericError; // failed to spawn connection
                    }
                    else
                        return VFSError::GenericError; // failed to find connection by uuid
                }
                else if( tag == VFSArchiveHost::Tag ) {
                    if( !has_string(g_HostInfoJunctionKey) )
                        return VFSError::GenericError; // invalid data
                    if( vfs.size() < 1 )
                        return VFSError::GenericError; // invalid data
                    
                    auto host = make_shared<VFSArchiveHost>( h[g_HostInfoJunctionKey].GetString(), vfs.back() );
                    vfs.emplace_back( host );
                }
                else if( tag == VFSArchiveUnRARHost::Tag ) {
                    if( !has_string(g_HostInfoJunctionKey) )
                        return VFSError::GenericError; // invalid data
                    if( vfs.size() < 1 || !vfs.back()->IsNativeFS() )
                        return VFSError::GenericError; // invalid data
                    
                    auto host = make_shared<VFSArchiveUnRARHost>( h[g_HostInfoJunctionKey].GetString() );
                    vfs.emplace_back( host );
                }
                // ...
            }
        }
        catch(VFSErrorException &ee) {
            return ee.code();
        }
        if( !vfs.empty() )
            _host = vfs.back();
        return VFSError::Ok;
    }
    
    return VFSError::GenericError;
}

string PanelDataPersisency::GetPathFromState( const rapidjson::StandaloneValue &_state )
{
    if( _state.IsObject() && _state.HasMember(g_StackPathKey) && _state[g_StackPathKey].IsString() )
        return _state[g_StackPathKey].GetString();
    
    return "";
}
