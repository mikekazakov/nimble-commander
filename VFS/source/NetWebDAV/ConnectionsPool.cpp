// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConnectionsPool.h"
#include "Internal.h"
#include <Habanero/StringViewZBuf.h>

namespace nc::vfs::webdav {

constexpr static const struct timeval g_SelectTimeout = {0, 600 * 1000}; // 600ms
constexpr static const struct timeval g_SelectWait = {0, 100 * 1000};    // 100ms

static CURL *SpawnOrThrow()
{
    const auto curl = curl_easy_init();
    if( !curl )
        throw std::runtime_error("curl_easy_init() has returned NULL");
    return curl;
}

static size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp)
{
    const auto sz = size * nmemb;
    auto &str = *reinterpret_cast<std::string *>(userp);
    str.insert(str.size(), reinterpret_cast<const char *>(buffer), sz);
    return sz;
}

static bool SelectMulti(CURLM *_multi)
{
    fd_set fdread, fdwrite, fdexcep;
    int maxfd = -1;
    FD_ZERO(&fdread);
    FD_ZERO(&fdwrite);
    FD_ZERO(&fdexcep);
    const CURLMcode mc = curl_multi_fdset(_multi, &fdread, &fdwrite, &fdexcep, &maxfd);
    if( mc != CURLM_OK ) {
        return false;
    }

    int select_rc = -1;
    if( maxfd == -1 ) {
        struct timeval timeout = g_SelectWait;
        select_rc = select(0, NULL, NULL, NULL, &timeout);
    }
    else {
        struct timeval timeout = g_SelectTimeout;
        select_rc = select(maxfd + 1, &fdread, &fdwrite, &fdexcep, &timeout);
    }
    return select_rc != -1;
}

static int ErrorIfAny(CURLM *_multi)
{
    CURLMsg *msg;
    int msgs_left = 0;
    while( (msg = curl_multi_info_read(_multi, &msgs_left)) != nullptr ) {
        if( msg->msg == CURLMSG_DONE ) {
            const auto curle_rc = msg->data.result;
            if( curle_rc != CURLE_OK )
                return ToVFSError(curle_rc, 0);

            const auto http_rc = curl_easy_get_response_code(msg->easy_handle);
            if( http_rc >= 300 )
                return ToVFSError(curle_rc, http_rc);
        }
    }
    return VFSError::Ok;
}

Connection::Connection(const HostConfiguration &_config)
    : m_EasyHandle(SpawnOrThrow()), m_RequestHeader(nullptr, &curl_slist_free_all)
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
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, ReadBuffer::Write);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &m_ResponseBody);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &m_ResponseHeader);
}

Connection::~Connection()
{
    curl_easy_cleanup(m_EasyHandle);

    if( m_MultiHandle )
        curl_multi_cleanup(m_MultiHandle);
}

int Connection::Progress(void *_clientp, long _dltotal, long _dlnow, long _ultotal, long _ulnow)
{
    const auto &connection = *(Connection *)_clientp;
    if( !connection.m_ProgressCallback )
        return 0;
    const auto go_on = connection.m_ProgressCallback(_dltotal, _dlnow, _ultotal, _ulnow);
    return go_on ? 0 : 1;
}

void Connection::SetProgreessCallback(ProgressCallback _callback)
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
    curl_easy_setopt(m_EasyHandle, CURLOPT_NOBODY, 0);
    m_ProgressCallback = nullptr;
    m_Paused = false;
    m_RequestHeader.reset();
    m_RequestBody.Clear();
    m_ResponseHeader.clear();
    m_ResponseBody.Clear();
}

int Connection::SetCustomRequest(std::string_view _request)
{
    base::StringViewZBuf<64> request(_request);
    const auto rc = curl_easy_setopt(m_EasyHandle, CURLOPT_CUSTOMREQUEST, request.c_str());
    return CurlRCToVFSError(rc);
}

int Connection::SetURL(std::string_view _url)
{
    base::StringViewZBuf<512> url(_url);
    const auto rc = curl_easy_setopt(m_EasyHandle, CURLOPT_URL, url.c_str());
    return CurlRCToVFSError(rc);
}

int Connection::SetHeader(std::span<const std::string_view> _header)
{
    struct curl_slist *chunk = nullptr;

    for( const auto &element : _header ) {
        base::StringViewZBuf<512> element_nt(element);
        chunk = curl_slist_append(chunk, element_nt.c_str());
    }

    m_RequestHeader.reset(chunk);
    const auto rc = curl_easy_setopt(m_EasyHandle, CURLOPT_HTTPHEADER, m_RequestHeader.get());
    return CurlRCToVFSError(rc);
}

int Connection::SetBody(std::span<const std::byte> _body)
{
    m_RequestBody.Write(_body.data(), _body.size_bytes());

    curl_easy_setopt(m_EasyHandle, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READFUNCTION, WriteBuffer::ReadCURL);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READDATA, &m_RequestBody);
    curl_easy_setopt(
        m_EasyHandle, CURLOPT_INFILESIZE_LARGE, static_cast<curl_off_t>(m_RequestBody.Size()));

    // TODO: mb check rcs from curl?
    return VFSError::Ok;
}

int Connection::SetNonBlockingUpload(size_t _upload_size)
{
    curl_easy_setopt(m_EasyHandle, CURLOPT_UPLOAD, 1L);
    //    curl_easy_setopt(m_EasyHandle, CURLOPT_READFUNCTION, WriteBuffer::Read);
    //    curl_easy_setopt(m_EasyHandle, CURLOPT_READDATA, &m_RequestBody);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READFUNCTION, ReadFromWriteBuffer);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READDATA, this);
    curl_easy_setopt(m_EasyHandle, CURLOPT_INFILESIZE_LARGE, static_cast<curl_off_t>(_upload_size));

    // TODO: mb check rcs from curl?
    return VFSError::Ok;
}

WriteBuffer &Connection::RequestBody()
{
    return m_RequestBody;
}

ReadBuffer &Connection::ResponseBody()
{
    return m_ResponseBody;
}

std::string_view Connection::ResponseHeader()
{
    return m_ResponseHeader;
}

Connection::BlockRequestResult Connection::PerformBlockingRequest()
{
    const auto curl_rc = curl_easy_perform(m_EasyHandle);
    const auto http_rc = curl_easy_get_response_code(m_EasyHandle);
    return {CurlRCToVFSError(curl_rc), http_rc};
}

int Connection::ReadBodyUpToSize(size_t _target)
{
    if( m_MultiHandle == nullptr || m_MultiHandleAttached == false )
        return VFSError::InvalidCall;

    if( m_ResponseBody.Size() >= _target )
        return VFSError::Ok;

    const auto multi = m_MultiHandle;

    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
        ;

    while( m_ResponseBody.Size() < _target && running_handles != 0 ) {
        if( SelectMulti(multi) == false ) {
            return VFSError::FromErrno();
        }
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
            ;
    }

    if( running_handles == 0 )
        return ErrorIfAny(multi);
    else
        return VFSError::Ok;
}

size_t Connection::ReadFromWriteBuffer(void *_ptr, size_t _size, size_t _nmemb, void *_userp)
{
    auto &connection = *reinterpret_cast<Connection *>(_userp);

    auto &write_buffer = connection.m_RequestBody;
    if( write_buffer.Empty() ) {
        connection.m_Paused = true;
        return CURL_READFUNC_PAUSE;
    }

    const auto bytes = _size * _nmemb;
    return write_buffer.Read(_ptr, bytes);
}

int Connection::WriteBodyUpToSize(size_t _target)
{
    if( m_MultiHandle == nullptr || m_MultiHandleAttached == false )
        return VFSError::InvalidCall;

    if( m_RequestBody.Size() < _target )
        return VFSError::InvalidCall;

    const size_t target_buffer_size = m_RequestBody.Size() - _target;

    const auto multi = m_MultiHandle;

    if( m_Paused == true ) {
        curl_easy_pause(m_EasyHandle, CURLPAUSE_CONT);
        m_Paused = false;
    }

    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
        ;

    do {
        if( SelectMulti(multi) == false ) {
            return VFSError::FromErrno();
        }
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
            ;
    } while( m_RequestBody.Size() > target_buffer_size && running_handles != 0 );

    if( running_handles == 0 )
        return ErrorIfAny(multi);
    else
        return VFSError::Ok;
}

ConnectionsPool::ConnectionsPool(const HostConfiguration &_config) : m_Config(_config)
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
    m_Connections.emplace_back(std::move(_connection));
}

ConnectionsPool::AR::AR(std::unique_ptr<Connection> _c, ConnectionsPool &_p)
    : connection(std::move(_c)), pool(_p)
{
}

ConnectionsPool::AR::~AR()
{
    if( connection )
        pool.Return(std::move(connection));
}

} // namespace nc::vfs::webdav
