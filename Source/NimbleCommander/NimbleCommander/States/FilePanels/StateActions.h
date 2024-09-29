// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"
#include <ankerl/unordered_dense.h>
#include <memory>

namespace nc::config {
class Config;
}

namespace nc::utility {
class TemporaryFileStorage;
class NativeFSManager;
} // namespace nc::utility

namespace nc::panel {
class TagsStorage;
class NetworkConnectionsManager;

using StateActionsMap = ankerl::unordered_dense::map<SEL, std::unique_ptr<const actions::StateAction>>;

StateActionsMap BuildStateActionsMap(nc::config::Config &_global_config,
                                     nc::panel::NetworkConnectionsManager &_net_mgr,
                                     nc::utility::TemporaryFileStorage &_temp_file_storage,
                                     nc::utility::NativeFSManager &_native_fs_manager,
                                     const nc::panel::TagsStorage &_tags_storage);

} // namespace nc::panel
