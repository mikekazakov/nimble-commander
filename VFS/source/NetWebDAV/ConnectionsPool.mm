#include "ConnectionsPool.h"
#include "Internal.h"

namespace nc::vfs::webdav {

static CURL *SpawnOrThrow()
{
    const auto curl = curl_easy_init();
    if( !curl )
        throw runtime_error("curl_easy_init() has returned NULL");
    return curl;
}

Connection::Connection( const HostConfiguration& _config ):
    m_EasyHandle(SpawnOrThrow())
{
    curl_easy_setopt(m_EasyHandle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC | CURLAUTH_DIGEST);
    curl_easy_setopt(m_EasyHandle, CURLOPT_USERNAME, _config.user.c_str());
    curl_easy_setopt(m_EasyHandle, CURLOPT_PASSWORD, _config.passwd.c_str());
}

Connection::~Connection()
{
    curl_easy_cleanup(m_EasyHandle);
}

CURL *Connection::EasyHandle()
{
    return m_EasyHandle;
}

void Connection::Clear()
{
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
        return AR{make_unique<Connection>(m_Config), *this};
    }
    else {
        unique_ptr<Connection> c = move(m_Connections.front());
        m_Connections.pop_front();
        return AR{move(c), *this};
    }
}

void ConnectionsPool::Return(unique_ptr<Connection> _connection)
{
    if( !_connection )
        throw invalid_argument("ConnectionsPool::Return accepts only valid connections");

    _connection->Clear();
    m_Connections.emplace_back( move(_connection) );
}

ConnectionsPool::AR::AR(unique_ptr<Connection> _c, ConnectionsPool& _p):
    connection( move(_c) ),
    pool(_p)
{
}

ConnectionsPool::AR::~AR()
{
    if( connection )
        pool.Return( move(connection) );
}

}
