// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <vector>
#include <memory>
#include <string_view>
#include <span>
#include <limits>
#include <VFS/VFSError.h>
#include "ReadBuffer.h"
#include "WriteBuffer.h"
#include "Connection.h"

namespace nc::vfs::webdav {

class HostConfiguration;

class ConnectionsPool
{
public:
    ConnectionsPool(const HostConfiguration &_config);
    ~ConnectionsPool();

    struct AR;
    AR Get();
    std::unique_ptr<Connection> GetRaw();
    void Return(std::unique_ptr<Connection> _connection);

private:
    std::vector<std::unique_ptr<Connection>> m_Connections;
    const HostConfiguration &m_Config;
};

struct ConnectionsPool::AR {
    AR(std::unique_ptr<Connection> _c, ConnectionsPool &_p);
    AR(AR &&) = default;
    ~AR();
    std::unique_ptr<Connection> connection;
    ConnectionsPool &pool;
};

} // namespace nc::vfs::webdav
