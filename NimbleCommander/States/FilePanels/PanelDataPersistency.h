#pragma once

#include <VFS/VFS.h>
#include "../../Core/rapidjson.h"

class PanelDataPersisency
{
public:
    struct Location
    {
        inline bool is_native() const { return hosts.empty(); }
        vector<any> hosts; // .front() is a deepest host, .back() is topmost
                           // empty hosts means using native vfs
        string path;
    };

    static string MakeFootprintString( const Location &_loc );
    static size_t MakeFootprintStringHash( const Location &_loc );
    
    static string MakeVerbosePathString( const Location &_loc );
//    static string MakeFootprintString( const VFSHost &_at_vfs, const string &_path );

    static optional<Location> EncodeLocation( const VFSHost &_vfs, const string &_path );
    
 
    using json = rapidjson::StandaloneValue;
    static optional<json> EncodeVFSPath( const VFSHost &_vfs, const string &_path );
    static optional<json> EncodeVFSPath( const VFSListing &_listing );
    
    static optional<Location> JSONToLocation( const json &_json );
    static optional<json> LocationToJSON( const Location &_location );
    
    // LocationToJSON( *EncodeLocation(host, path) ) == EncodeVFSPath(host, path)
    

    static int CreateVFSFromState( const json &_state, VFSHostPtr &_host );
    static int CreateVFSFromLocation( const Location _state, VFSHostPtr &_host );
    
    static string GetPathFromState( const json &_state );
    
    
/**
{
 hosts_v1: [...]
 path: "/erere/rere/trtr"
}
*/
    static optional<json> EncodeVFSHostInfo( const VFSHost& _host );

    
/*
Host info:
{
type: "type", // VFSNativeHost::Tag, VFSPSHost::Tag, VFSArchiveHost::Tag, VFSArchiveUnRARHost::Tag, VFSXAttrHost::Tag, "network"
              // perhaps "archive" in the future, when more of them will come and some dedicated "ArchiveManager" will appear

// for xattr, archives
junction: "path"

// for network:
uuid: "uuid"
}
 
 */
};
