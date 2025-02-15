// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Panel/NetworkConnectionsManager.h>
#include <Config/RapidJSON_fwd.h>
#include <any>
#include <vector>

// these routines implicitly use the following components:
// 1. NetworkConnectionsManager

namespace nc::core {
class VFSInstanceManager;
}

namespace nc::panel {

struct PersistentLocation {
    bool is_native() const noexcept;
    bool is_network() const noexcept;
    std::vector<std::any> hosts; // .front() is a deepest host, .back() is topmost
                                 // empty hosts means using native vfs
    std::string path;
};

class PanelDataPersistency
{
public:
    PanelDataPersistency(NetworkConnectionsManager &_conn_manager);

    std::string MakeFootprintString(const PersistentLocation &_loc);
    size_t MakeFootprintStringHash(const PersistentLocation &_loc);

    // NB! these functions theat paths as a directory regardless, and resulting path will
    // containt a trailing slash.
    std::string MakeVerbosePathString(const PersistentLocation &_loc);
    std::string MakeVerbosePathString(const VFSHost &_host, const std::string &_directory);

    std::optional<PersistentLocation> EncodeLocation(const VFSHost &_vfs, const std::string &_path);

    std::optional<NetworkConnectionsManager::Connection>
    ExtractConnectionFromLocation(const PersistentLocation &_location);

    // the following functions will return kNullType in case of error
    using json = nc::config::Value;
    json EncodeVFSPath(const VFSHost &_vfs, const std::string &_path);
    json EncodeVFSPath(const VFSListing &_listing);
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ these functions should be replaced by the following chain:
    // VFSHost+Path or VFSListing => PersistentLocation => JSON representation

    std::optional<PersistentLocation> JSONToLocation(const json &_json);
    json LocationToJSON(const PersistentLocation &_location);

    // LocationToJSON( *EncodeLocation(host, path) ) == EncodeVFSPath(host, path)

    // uses current state to retrieve existing vfs if possible
    std::expected<VFSHostPtr, Error> CreateVFSFromLocation(const PersistentLocation &_state,
                                                           core::VFSInstanceManager &_inst_mgr);

    std::string GetPathFromState(const json &_state);

    /**
    {
     hosts_v1: [...]
     path: "/erere/rere/trtr"
    }
    */
    json EncodeVFSHostInfo(const VFSHost &_host);

    /*
    Host info:
    {
    type: "type", // VFSNativeHost::Tag, VFSPSHost::Tag, VFSArchiveHost::Tag, VFSArchiveUnRARHost::Tag,
    VFSXAttrHost::Tag, "network"
                  // perhaps "archive" in the future, when more of them will come and some dedicated "ArchiveManager"
    will appear

    // for xattr, archives
    junction: "path"

    // for network:
    uuid: "uuid"
    }

     */

private:
    std::any EncodeState(const VFSHost &_host);

    bool Fits(VFSHost &_alive, const std::any &_encoded);

    VFSHostPtr FindFitting(const std::vector<std::weak_ptr<VFSHost>> &_hosts,
                           const std::any &_encoded,
                           const VFSHost *_parent /* may be nullptr */);

    NetworkConnectionsManager &m_ConnectionsManager;
};

} // namespace nc::panel
