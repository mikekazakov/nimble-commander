// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <functional>
#include <vector>
#include <memory>

namespace nc::vfs::webdav {

class HostConfiguration;

class Connection
{
public:
    Connection( const HostConfiguration& _config );
    ~Connection();

    CURL *EasyHandle();
    CURLM *MultiHandle();

    bool IsMultiHandleAttached() const;
    void AttachMultiHandle();
    void DetachMultiHandle();

    using ProgressCallback = std::function<bool(long _dltotal, long _dlnow, long _ultotal, long _ulnow)>;
    void SetProgreessCallback( ProgressCallback _callback );
    void Clear();



private:
    void operator=(const Connection&) = delete;
    Connection(const Connection&) = delete;
    static int Progress(void *_clientp, long _dltotal, long _dlnow, long _ultotal, long _ulnow);

    CURL * const    m_EasyHandle = nullptr;
    CURLM *         m_MultiHandle = nullptr;
    bool            m_MultiHandleAttached = false;
    ProgressCallback m_ProgressCallback;
};

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
    std::vector< std::unique_ptr<Connection> > m_Connections;
    const HostConfiguration &m_Config;
};

struct ConnectionsPool::AR
{
    AR( std::unique_ptr<Connection> _c, ConnectionsPool& _p );
    AR( AR && ) = default;
    ~AR();
    std::unique_ptr<Connection> connection;
    ConnectionsPool& pool;
};




}
