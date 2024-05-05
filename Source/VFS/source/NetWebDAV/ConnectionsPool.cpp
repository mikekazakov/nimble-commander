// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConnectionsPool.h"
#include "Internal.h"
#include "CURLConnection.h"

namespace nc::vfs::webdav {

ConnectionsPool::ConnectionsPool(const HostConfiguration &_config) : m_Config(_config)
{
}

ConnectionsPool::~ConnectionsPool() = default;

ConnectionsPool::AR ConnectionsPool::Get()
{
    if( m_Connections.empty() ) {
        return AR{std::make_unique<CURLConnection>(m_Config), *this};
    }
    else {
        std::unique_ptr<Connection> c = std::move(m_Connections.back());
        m_Connections.pop_back();
        return AR{std::move(c), *this};
    }
}

std::unique_ptr<Connection> ConnectionsPool::GetRaw()
{
    auto ar = Get();
    auto c = std::move(ar.connection);
    return c;
}

void ConnectionsPool::Return(std::unique_ptr<Connection> _connection)
{
    if( !_connection )
        throw std::invalid_argument("ConnectionsPool::Return accepts only valid connections");

    _connection->Clear();
    m_Connections.emplace_back(std::move(_connection));
}

ConnectionsPool::AR::AR(std::unique_ptr<Connection> _c, ConnectionsPool &_p) : connection(std::move(_c)), pool(_p)
{
}

ConnectionsPool::AR::~AR()
{
    if( connection )
        pool.Return(std::move(connection));
}

} // namespace nc::vfs::webdav
