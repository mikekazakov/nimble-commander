#include "vfs/vfs_native.h"
#include "vfs/vfs_arc_la.h"
#include "vfs/vfs_arc_unrar.h"
#include "vfs/vfs_ps.h"
#include "vfs/vfs_xattr.h"
#include "vfs/vfs_net_ftp.h"
#include "vfs/vfs_net_sftp.h"
#include "PanelDataPersistency.h"

//type: "type", // VFSNativeHost::Tag, VFSPSHost::Tag, VFSArchiveHost::Tag, VFSArchiveUnRARHost::Tag, VFSXAttrHost::Tag, "network"
// perhaps "archive" in the future, when more of them will come and some dedicated "ArchiveManager" will appear
//junction: "path"

static const auto g_StackHostsKey = "hosts_v1";
static const auto g_StackPathKey = "path";
static const auto g_HostInfoTypeKey = "type";
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
    auto h = _listing.Host().get();
    while( h ) {
        hosts.emplace_back( h );
        h = h->Parent().get();
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
    if( _host.FSTag() == VFSNativeHost::Tag ) {
        rapidjson::StandaloneValue json(rapidjson::kObjectType);
        json.AddMember(rapidjson::StandaloneValue(g_HostInfoTypeKey, rapidjson::g_CrtAllocator),
                       rapidjson::StandaloneValue(VFSNativeHost::Tag, rapidjson::g_CrtAllocator),
                       rapidjson::g_CrtAllocator);
        return move(json);
    }
    return nullopt;
}

int PanelDataPersisency::CreateVFSFromState( const rapidjson::StandaloneValue &_state, VFSHostPtr &_host )
{
    if( _state.IsObject() && _state.HasMember(g_StackHostsKey) && _state[g_StackHostsKey].IsArray() ) {
        auto &hosts = _state[g_StackHostsKey];
        vector<VFSHostPtr> vfs;
        
        for( auto i = hosts.Begin(), e = hosts.End(); i != e; ++i ) {
            auto &h = *i;
            if( string_view(h[g_HostInfoTypeKey].GetString()) == VFSNativeHost::Tag ) {
                vfs.emplace_back( VFSNativeHost::SharedHost() );
            }
            // ...
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
