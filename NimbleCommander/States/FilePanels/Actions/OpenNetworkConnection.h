// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

class NetworkConnectionsManager;

namespace nc::panel::actions {

struct OpenConnectionBase : PanelAction
{
    OpenConnectionBase( NetworkConnectionsManager &_net_mgr );
protected:
    NetworkConnectionsManager &m_NetMgr;
};
    
struct OpenNewFTPConnection final : OpenConnectionBase
{
    OpenNewFTPConnection(NetworkConnectionsManager &_net_mgr );
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewSFTPConnection final : OpenConnectionBase
{
    OpenNewSFTPConnection(NetworkConnectionsManager &_net_mgr );
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewWebDAVConnection final : OpenConnectionBase
{
    OpenNewWebDAVConnection(NetworkConnectionsManager &_net_mgr );
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewDropboxStorage final : OpenConnectionBase
{
    OpenNewDropboxStorage(NetworkConnectionsManager &_net_mgr);
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewLANShare final : OpenConnectionBase
{
    OpenNewLANShare(NetworkConnectionsManager &_net_mgr);
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNetworkConnections final : OpenConnectionBase
{
    OpenNetworkConnections(NetworkConnectionsManager &_net_mgr);
    void Perform( PanelController *_target, id _sender ) const override;
};

// will extract additional context from _sender.representedObject
struct OpenExistingNetworkConnection final : OpenConnectionBase
{
    OpenExistingNetworkConnection(NetworkConnectionsManager &_net_mgr);
    void Perform( PanelController *_target, id _sender ) const override;
};

}
