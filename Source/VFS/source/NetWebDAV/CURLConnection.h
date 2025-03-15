// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Connection.h"
#include "ReadBuffer.h"
#include "WriteBuffer.h"

#include <curl/curl.h>
#include <memory>
#include <functional>

namespace nc::vfs::webdav {

class HostConfiguration;

class CURLConnection : public Connection
{
public:
    CURLConnection(const HostConfiguration &_config);
    ~CURLConnection();

    void Clear() override;

    std::expected<void, Error> SetCustomRequest(std::string_view _request) override;

    std::expected<void, Error> SetURL(std::string_view _url) override;

    std::expected<void, Error> SetHeader(std::span<const std::string_view> _header) override;

    std::expected<void, Error> SetBody(std::span<const std::byte> _body) override;

    std::expected<void, Error> SetNonBlockingUpload(size_t _upload_size) override;

    void MakeNonBlocking() override;

    std::expected<int, Error> PerformBlockingRequest() override;

    WriteBuffer &RequestBody() override;

    ReadBuffer &ResponseBody() override;

    std::string_view ResponseHeader() override;

    std::expected<void, Error> ReadBodyUpToSize(size_t _target) override;

    std::expected<void, Error> WriteBodyUpToSize(size_t _target) override;

private:
    using SlistPtr = std::unique_ptr<struct curl_slist, decltype(&curl_slist_free_all)>;
    using ProgressCallback = std::function<bool(long _dltotal, long _dlnow, long _ultotal, long _ulnow)>;

    void operator=(const CURLConnection &) = delete;
    CURLConnection(const CURLConnection &) = delete;
    void DetachMultiHandle();
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

} // namespace nc::vfs::webdav
