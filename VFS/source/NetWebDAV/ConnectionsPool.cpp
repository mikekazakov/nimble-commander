// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConnectionsPool.h"
#include "Internal.h"

namespace nc::vfs::webdav {

static CURL *SpawnOrThrow()
{
    const auto curl = curl_easy_init();
    if( !curl )
        throw std::runtime_error("curl_easy_init() has returned NULL");
    return curl;
}

Connection::Connection( const HostConfiguration& _config ):
    m_EasyHandle(SpawnOrThrow())
{
    const auto auth_methods = CURLAUTH_BASIC | CURLAUTH_DIGEST;
    const auto ua = "Nimble Commander";
    const auto curl = m_EasyHandle;
    curl_easy_setopt(curl, CURLOPT_HTTPAUTH, auth_methods);
    curl_easy_setopt(curl, CURLOPT_USERNAME, _config.user.c_str());
    curl_easy_setopt(curl, CURLOPT_PASSWORD, _config.passwd.c_str());
    curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, Progress);
    curl_easy_setopt(curl, CURLOPT_XFERINFODATA, this);
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, ua);
    curl_easy_setopt(curl, CURLOPT_LOW_SPEED_LIMIT, 1L);
    curl_easy_setopt(curl, CURLOPT_LOW_SPEED_TIME, 60L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_PORT, long(_config.port));
    curl_easy_setopt(curl, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
}

Connection::~Connection()
{
    curl_easy_cleanup(m_EasyHandle);
    
    if( m_MultiHandle )
        curl_multi_cleanup(m_MultiHandle);
}

CURL *Connection::EasyHandle()
{
    return m_EasyHandle;
}

int Connection::Progress(void *_clientp, long _dltotal, long _dlnow, long _ultotal, long _ulnow)
{
    const auto &connection = *(Connection*)_clientp;
    if( !connection.m_ProgressCallback )
        return 0;
    const auto go_on = connection.m_ProgressCallback(_dltotal, _dlnow, _ultotal, _ulnow);
    return go_on ? 0 : 1;
}

void Connection::SetProgreessCallback( ProgressCallback _callback )
{
    m_ProgressCallback = _callback;
}

CURLM *Connection::MultiHandle()
{
    return m_MultiHandle;
}

bool Connection::IsMultiHandleAttached() const
{
    return m_MultiHandleAttached;
}

void Connection::AttachMultiHandle()
{
    if( m_MultiHandleAttached )
        return;
    
    if( !m_MultiHandle )
        m_MultiHandle = curl_multi_init();

    const auto e = curl_multi_add_handle(m_MultiHandle, m_EasyHandle);
    if( e == CURLM_OK )
        m_MultiHandleAttached = true;
}

void Connection::DetachMultiHandle()
{
    if( !m_MultiHandleAttached )
        return;
    
    const auto e = curl_multi_remove_handle(m_MultiHandle, m_EasyHandle);
    if( e == CURLM_OK )
        m_MultiHandleAttached = false;
}

void Connection::Clear()
{
    DetachMultiHandle();

    curl_easy_setopt(m_EasyHandle, CURLOPT_CUSTOMREQUEST, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_HTTPHEADER, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_URL, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_UPLOAD, 0L);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READFUNCTION, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READDATA, stdin);
    curl_easy_setopt(m_EasyHandle, CURLOPT_SEEKFUNCTION, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_SEEKDATA, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_INFILESIZE_LARGE, -1l);
    curl_easy_setopt(m_EasyHandle, CURLOPT_WRITEFUNCTION, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_WRITEDATA, stdout);
    curl_easy_setopt(m_EasyHandle, CURLOPT_HEADERFUNCTION, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_HEADERDATA, nullptr);
    curl_easy_setopt(m_EasyHandle, CURLOPT_NOBODY, 0);
    m_ProgressCallback = nullptr;
}

ConnectionsPool::ConnectionsPool(const HostConfiguration &_config):
    m_Config(_config)
{
}

ConnectionsPool::~ConnectionsPool()
{
}

ConnectionsPool::AR ConnectionsPool::Get()
{
    if( m_Connections.empty() ) {
        return AR{std::make_unique<Connection>(m_Config), *this};
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
    m_Connections.emplace_back( std::move(_connection) );
}

ConnectionsPool::AR::AR(std::unique_ptr<Connection> _c, ConnectionsPool& _p):
    connection( std::move(_c) ),
    pool(_p)
{
}

ConnectionsPool::AR::~AR()
{
    if( connection )
        pool.Return( std::move(connection) );
}

}
