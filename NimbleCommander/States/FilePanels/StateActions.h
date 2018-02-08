// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"

class NetworkConnectionsManager;

namespace nc::panel {
    
using StateActionsMap = unordered_map<SEL, unique_ptr<const actions::StateAction> >;
StateActionsMap BuildStateActionsMap(NetworkConnectionsManager &_net_mgr);
    
}
