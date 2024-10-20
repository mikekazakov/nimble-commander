// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Panel/NetworkConnectionsManager.h>
#include "VFSInstancePromise.h"

class NetworkConnectionIconProvider
{
public:
    static NSImage *Icon16px(const nc::panel::NetworkConnectionsManager::Connection &_connection);

    /**
     * May return nil if _promise describes not a network vfs known to NetworkConnectionIconProvider
     */
    static NSImage *Icon16px(const nc::core::VFSInstancePromise &_promise);

    static NSImage *Icon16px(const VFSHost &_host);

private:
};
