#pragma once

#include "../../../Files/3rd_party/built/include/curl/curl.h"

namespace nc::vfs::webdav {

class HostConfiguration;

class Connection
{
public:
    Connection( const HostConfiguration& _config );
    ~Connection();

    CURL *EasyHandle();
    
    void Clear();

private:
    void operator=(const Connection&) = delete;
    Connection(const Connection&) = delete;

    CURL * const m_EasyHandle;
};



class ConnectionsPool
{
public:
    ConnectionsPool(const HostConfiguration &_config);
    ~ConnectionsPool();

    struct AR;

    AR Get();
    void Return(unique_ptr<Connection> _connection);



private:
    deque< unique_ptr<Connection> > m_Connections;
    const HostConfiguration &m_Config;
};

struct ConnectionsPool::AR
{
    AR( unique_ptr<Connection> _c, ConnectionsPool& _p );
    AR( AR && ) = default;
    ~AR();
    unique_ptr<Connection> connection;
    ConnectionsPool& pool;
};




}
