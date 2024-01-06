// Copyright (C) 2018-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"
#include <robin_hood.h>
#include <memory>

class NetworkConnectionsManager;

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::config {
class Config;
}

namespace nc::utility {
class TemporaryFileStorage;
class NativeFSManager;
} // namespace nc::utility

namespace nc::panel {

using StateActionsMap =
    robin_hood::unordered_flat_map<SEL, std::unique_ptr<const actions::StateAction>>;

StateActionsMap BuildStateActionsMap(nc::config::Config &_global_config,
                                 NetworkConnectionsManager &_net_mgr,
                                 nc::utility::TemporaryFileStorage &_temp_file_storage,
                                 nc::utility::NativeFSManager &_native_fs_manager,
                                 nc::bootstrap::ActivationManager &_activation_manager);

} // namespace nc::panel
