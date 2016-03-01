#pragma once

#include "vfs/VFS.h"
#include "rapidjson.h"

class PanelDataPersisency
{
public:
    static optional<rapidjson::StandaloneValue> EncodeVFSPath( const VFSListing &_listing );

    static int CreateVFSFromState( const rapidjson::StandaloneValue &_state, VFSHostPtr &_host );
    static string GetPathFromState( const rapidjson::StandaloneValue &_state );
    
/**
{
 hosts_v1: [...]
 path: "/erere/rere/trtr"
}
*/
    static optional<rapidjson::StandaloneValue> EncodeVFSHostInfo( const VFSHost& _host );

    
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

