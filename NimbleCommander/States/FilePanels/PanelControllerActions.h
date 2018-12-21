// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"
#include <Utility/NativeFSManager.h>
#include <unordered_map>

class NetworkConnectionsManager;

namespace nc::panel {

using PanelActionsMap = std::unordered_map<SEL, std::unique_ptr<const actions::PanelAction> >;
PanelActionsMap BuildPanelActionsMap(NetworkConnectionsManager& _net_mgr,
                                     utility::NativeFSManager& _native_fs_mgr);
    
}
