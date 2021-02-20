// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <functional>
#include <vector>
#include <memory>
#include <string_view>
#include <span>
#include <limits>
#include <VFS/VFSError.h>
#include "ReadBuffer.h"
#include "WriteBuffer.h"

namespace nc::vfs::webdav {

class HostConfiguration;

// TODO: "NonBlocking" is a lie - it's blocking. Need to find a better term
class Connection
{
public:
    struct BlockRequestResult {
        int vfs_error = VFSError::Ok; // error code for the underlying transport
        int http_code = 0;            // actual protocol result
    };
    static constexpr size_t ConcludeBodyWrite = std::numeric_limits<size_t>::max() - 1;
    static constexpr size_t AbortBodyWrite = std::numeric_limits<size_t>::max() - 2;
    static constexpr size_t AbortBodyRead = std::numeric_limits<size_t>::max() - 1;

    Connection(const HostConfiguration &_config);
    ~Connection();

    bool IsMultiHandleAttached() const;
    void AttachMultiHandle();
    void DetachMultiHandle();

    // Setting a request up. All these functions copy the input data
    int SetCustomRequest(std::string_view _request);
    int SetURL(std::string_view _url);
    int SetHeader(std::span<const std::string_view> _header);
    int SetBody(std::span<const std::byte> _body);
    int SetNonBlockingUpload(size_t _upload_size);

    // Queries
    BlockRequestResult PerformBlockingRequest();
    WriteBuffer &RequestBody();
    ReadBuffer &ResponseBody();
    std::string_view ResponseHeader();

    // "Multi" interface
    // AbortBodyRead size abort a pending download
    int ReadBodyUpToSize(size_t _target);
    
    // assumes the data is already in RequestBody
    // ConcludeBodyWrite and AbortBodyWrite are special 'sizes' that make the function behave
    // differently.
    // ConcludeBodyWrite makes the connection to perform pending operations without stopping once a
    // buffer was drained. AbortBodyWrite makes the connection to softly abort pending operations.
    int WriteBodyUpToSize(size_t _target);
    
    
    void Clear(); // Resets the connection to a pristine state regarding settings

private:
    using SlistPtr = std::unique_ptr<struct curl_slist, decltype(&curl_slist_free_all)>;
    using ProgressCallback =
        std::function<bool(long _dltotal, long _dlnow, long _ultotal, long _ulnow)>;
    
    void operator=(const Connection &) = delete;
    Connection(const Connection &) = delete;
    void SetProgreessCallback(ProgressCallback _callback);
    static int Progress(void *_clientp, long _dltotal, long _dlnow, long _ultotal, long _ulnow);
    static size_t ReadFromWriteBuffer(void *_ptr, size_t _size, size_t _nmemb, void *_userp);

    CURL *const m_EasyHandle = nullptr;
    CURLM *m_MultiHandle = nullptr;
    bool m_MultiHandleAttached = false;
    bool m_Paused = false;
    ProgressCallback m_ProgressCallback;

    SlistPtr m_RequestHeader;
    WriteBuffer m_RequestBody;
    ReadBuffer m_ResponseBody;
    std::string m_ResponseHeader;
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
