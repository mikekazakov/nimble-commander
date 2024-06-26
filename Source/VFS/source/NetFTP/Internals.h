// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <VFS/Host.h>
#include "Cache.h"

namespace nc::vfs::ftp {

inline constexpr curl_ftpmethod g_CURLFTPMethod = CURLFTPMETHOD_SINGLECWD;
inline constexpr int g_CURLVerbose = 0;

struct CURLInstance {
    ~CURLInstance();

    int RunningHandles()
    {
        int running_handles = 0;
        call_lock.lock();
        curl_multi_perform(curlm, &running_handles);
        call_lock.unlock();
        return running_handles;
    }

    template <typename T>
    inline CURLcode EasySetOpt(CURLoption _option, T _t)
    {
        return curl_easy_setopt(curl, _option, _t);
    }
    inline void EasyReset() { curl_easy_reset(curl); }

    bool IsAttached() const { return attached; }
    CURLMcode Attach();
    CURLMcode Detach();
    CURLcode PerformEasy();
    CURLcode PerformMulti();

    void EasySetupProgFunc(); // after this call client code can set/change prog_func, that will be
                              // called upon curl work and thus control it's flow
    void EasyClearProgFunc();

    CURL *curl = nullptr;
    CURLM *curlm = nullptr;
    bool attached = false;
    int (^prog_func)(double dltotal, double dlnow, double ultotal, double ulnow) = nil;
    std::mutex call_lock;

private:
    static int ProgressCallback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow);
};

struct ReadBuffer {
    ReadBuffer() { grow(default_capacity); }
    ~ReadBuffer() { free(buf); }
    ReadBuffer(const ReadBuffer &) = delete;
    ReadBuffer(const ReadBuffer &&) = delete;
    void operator=(const ReadBuffer &) = delete;

    void clear() { size = 0; }

    void add(const void *_mem, size_t _size)
    {
        if( capacity < size + _size )
            grow(size + static_cast<uint32_t>(_size));

        memcpy(buf + size, _mem, _size);
        size += _size;
    }

    void grow(uint32_t _new_size)
    {
        buf = static_cast<uint8_t *>(realloc(buf, capacity = static_cast<uint32_t>(_new_size)));
    }

    static size_t write_here_function(void *buffer, size_t size, size_t nmemb, void *userp)
    {
        ReadBuffer *buf = static_cast<ReadBuffer *>(userp);
        buf->add(buffer, size * nmemb);
        return size * nmemb;
    }

    void discard(size_t _sz)
    {
        assert(_sz <= size);
        memmove(buf, buf + _sz, size - _sz);
        size = size - static_cast<uint32_t>(_sz);
    }

    uint8_t *buf = 0;
    static const uint32_t default_capacity = 32768;
    uint32_t size = 0;
    uint32_t capacity = 0;
};

struct WriteBuffer {
    WriteBuffer();
    WriteBuffer(const WriteBuffer &) = delete;
    ~WriteBuffer();

    WriteBuffer &operator=(const WriteBuffer &) = delete;

    void clear();

    void add(const void *_mem, size_t _size);

    void grow(uint32_t _new_size);

    static size_t read_from_function(void *ptr, size_t size, size_t nmemb, void *data);

    void discard(size_t _sz);

    uint8_t *buf = 0;
    static const uint32_t default_capacity = 32768;
    uint32_t size = 0;
    uint32_t capacity = 0;
    uint32_t feed_size = 0; // amount of bytes fed to CURL
};

/**
 * User data should be a pointer to std::string
 */
size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp);

std::shared_ptr<Directory> ParseListing(const char *_str);

int CURLErrorToVFSError(CURLcode _curle);

} // namespace nc::vfs::ftp
