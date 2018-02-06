// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"

class NetworkConnectionsManager;

namespace nc::panel {

using PanelActionsMap = unordered_map<SEL, unique_ptr<const actions::PanelAction> >;
PanelActionsMap BuildPanelActionsMap(NetworkConnectionsManager& _net_mgr);
    
}
