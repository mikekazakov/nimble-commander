// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CURLConnection.h"
#include "Internal.h"
#include <Base/StackAllocator.h>
#include <cassert>

// CURL is full of macros with C-style casts
#pragma clang diagnostic ignored "-Wold-style-cast"

namespace nc::vfs::webdav {

constexpr static int g_CurlTimeoutMs = 30000; // 30s

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

static int curl_easy_get_response_code(CURL *_handle)
{
    assert(_handle != nullptr);
    long code = 0;
    curl_easy_getinfo(_handle, CURLINFO_RESPONSE_CODE, &code);
    return static_cast<int>(code);
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

CURLConnection::CURLConnection(const HostConfiguration &_config)
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

CURLConnection::~CURLConnection()
{
    curl_easy_cleanup(m_EasyHandle);

    if( m_MultiHandle )
        curl_multi_cleanup(m_MultiHandle);
}

int CURLConnection::Progress(void *_clientp, long _dltotal, long _dlnow, long _ultotal, long _ulnow)
{
    const auto &connection = *reinterpret_cast<CURLConnection *>(_clientp);
    if( !connection.m_ProgressCallback )
        return 0;
    const auto go_on = connection.m_ProgressCallback(_dltotal, _dlnow, _ultotal, _ulnow);
    return go_on ? 0 : 1;
}

void CURLConnection::SetProgreessCallback(ProgressCallback _callback)
{
    m_ProgressCallback = _callback;
}

void CURLConnection::MakeNonBlocking()
{
    if( m_MultiHandleAttached )
        return;

    if( !m_MultiHandle )
        m_MultiHandle = curl_multi_init();

    const auto e = curl_multi_add_handle(m_MultiHandle, m_EasyHandle);
    if( e == CURLM_OK )
        m_MultiHandleAttached = true;
}

void CURLConnection::DetachMultiHandle()
{
    if( !m_MultiHandleAttached )
        return;

    const auto e = curl_multi_remove_handle(m_MultiHandle, m_EasyHandle);
    if( e == CURLM_OK )
        m_MultiHandleAttached = false;
}

void CURLConnection::Clear()
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

int CURLConnection::SetCustomRequest(std::string_view _request)
{
    StackAllocator alloc;
    const std::pmr::string request(_request, &alloc);

    const auto rc = curl_easy_setopt(m_EasyHandle, CURLOPT_CUSTOMREQUEST, request.c_str());
    return CurlRCToVFSError(rc);
}

int CURLConnection::SetURL(std::string_view _url)
{
    StackAllocator alloc;
    const std::pmr::string url(_url, &alloc);
    const auto rc = curl_easy_setopt(m_EasyHandle, CURLOPT_URL, url.c_str());
    return CurlRCToVFSError(rc);
}

int CURLConnection::SetHeader(std::span<const std::string_view> _header)
{
    StackAllocator alloc;
    struct curl_slist *chunk = nullptr;

    std::pmr::string element_nt(&alloc);
    for( const auto &element : _header ) {
        element_nt = element;
        chunk = curl_slist_append(chunk, element_nt.c_str());
    }

    m_RequestHeader.reset(chunk);
    const auto rc = curl_easy_setopt(m_EasyHandle, CURLOPT_HTTPHEADER, m_RequestHeader.get());
    return CurlRCToVFSError(rc);
}

int CURLConnection::SetBody(std::span<const std::byte> _body)
{
    m_RequestBody.Write(_body.data(), _body.size_bytes());

    curl_easy_setopt(m_EasyHandle, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READFUNCTION, WriteBuffer::ReadCURL);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READDATA, &m_RequestBody);
    curl_easy_setopt(m_EasyHandle, CURLOPT_INFILESIZE_LARGE, static_cast<curl_off_t>(m_RequestBody.Size()));

    // TODO: mb check rcs from curl?
    return VFSError::Ok;
}

int CURLConnection::SetNonBlockingUpload(size_t _upload_size)
{
    curl_easy_setopt(m_EasyHandle, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READFUNCTION, ReadFromWriteBuffer);
    curl_easy_setopt(m_EasyHandle, CURLOPT_READDATA, this);
    curl_easy_setopt(m_EasyHandle, CURLOPT_INFILESIZE_LARGE, static_cast<curl_off_t>(_upload_size));

    // TODO: mb check rcs from curl?
    return VFSError::Ok;
}

WriteBuffer &CURLConnection::RequestBody()
{
    return m_RequestBody;
}

ReadBuffer &CURLConnection::ResponseBody()
{
    return m_ResponseBody;
}

std::string_view CURLConnection::ResponseHeader()
{
    return m_ResponseHeader;
}

Connection::BlockRequestResult CURLConnection::PerformBlockingRequest()
{
    const auto curl_rc = curl_easy_perform(m_EasyHandle);
    const auto http_rc = curl_easy_get_response_code(m_EasyHandle);
    return {.vfs_error = CurlRCToVFSError(curl_rc), .http_code = http_rc};
}

int CURLConnection::ReadBodyUpToSize(size_t _target)
{
    if( m_MultiHandle == nullptr || !m_MultiHandleAttached )
        return VFSError::InvalidCall;

    const auto multi = m_MultiHandle;

    if( _target == AbortBodyRead ) {
        SetProgreessCallback([](long, long, long, long) { return false; });
        int running_handles = 0;
        do {
            while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
                ;
        } while( running_handles );
        return VFSError::Ok;
    }

    if( m_ResponseBody.Size() >= _target )
        return VFSError::Ok;

    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
        ;

    while( m_ResponseBody.Size() < _target && running_handles != 0 ) {
        if( CURLM_OK != curl_multi_poll(multi, nullptr, 0, g_CurlTimeoutMs, nullptr) )
            break;
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
            ;
    }

    if( running_handles == 0 )
        return ErrorIfAny(multi);
    else
        return VFSError::Ok;
}

size_t CURLConnection::ReadFromWriteBuffer(void *_ptr, size_t _size, size_t _nmemb, void *_userp)
{
    auto &connection = *reinterpret_cast<CURLConnection *>(_userp);

    auto &write_buffer = connection.m_RequestBody;
    if( write_buffer.Empty() ) {
        connection.m_Paused = true;
        return CURL_READFUNC_PAUSE;
    }

    const auto bytes = _size * _nmemb;
    return write_buffer.Read(_ptr, bytes);
}

int CURLConnection::WriteBodyUpToSize(size_t _target)
{
    if( m_MultiHandle == nullptr || !m_MultiHandleAttached )
        return VFSError::InvalidCall;

    const auto multi = m_MultiHandle;

    if( _target == ConcludeBodyWrite || _target == AbortBodyWrite ) {
        if( _target == AbortBodyWrite )
            SetProgreessCallback([](long, long, long, long) { return false; });

        if( m_Paused ) {
            curl_easy_pause(m_EasyHandle, CURLPAUSE_CONT);
            m_Paused = false;
        }

        int running_handles = 0;
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
            ;

        if( running_handles == 0 )
            return ErrorIfAny(multi);

        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
            ;

        while( running_handles ) {
            if( CURLM_OK != curl_multi_poll(multi, nullptr, 0, g_CurlTimeoutMs, nullptr) )
                break;
            while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
                ;
        }
        return ErrorIfAny(multi);
    }

    if( m_RequestBody.Size() < _target )
        return VFSError::InvalidCall;

    const size_t target_buffer_size = m_RequestBody.Size() - _target;

    if( m_Paused ) {
        curl_easy_pause(m_EasyHandle, CURLPAUSE_CONT);
        m_Paused = false;
    }

    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
        ;

    do {
        if( CURLM_OK != curl_multi_poll(multi, nullptr, 0, g_CurlTimeoutMs, nullptr) )
            break;
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) )
            ;
    } while( m_RequestBody.Size() > target_buffer_size && running_handles != 0 );

    if( running_handles == 0 )
        return ErrorIfAny(multi);
    else
        return VFSError::Ok;
}

} // namespace nc::vfs::webdav
