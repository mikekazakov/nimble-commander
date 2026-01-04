// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel {
class NetworkConnectionsManager;
}

namespace nc::panel::actions {

struct OpenConnectionBase {
    OpenConnectionBase(NetworkConnectionsManager &_net_mgr);

    NetworkConnectionsManager &m_NetMgr;
};

struct OpenNewFTPConnection final : PanelAction, private OpenConnectionBase {
    OpenNewFTPConnection(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct OpenNewSFTPConnection final : PanelAction, private OpenConnectionBase {
    OpenNewSFTPConnection(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct OpenNewWebDAVConnection final : PanelAction, private OpenConnectionBase {
    OpenNewWebDAVConnection(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct OpenNewLANShare final : PanelAction, private OpenConnectionBase {
    OpenNewLANShare(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct OpenNetworkConnections final : PanelAction, private OpenConnectionBase {
    OpenNetworkConnections(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

// will extract additional context from _sender.representedObject
struct OpenExistingNetworkConnection final : PanelAction, private OpenConnectionBase {
    OpenExistingNetworkConnection(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

} // namespace nc::panel::actions
