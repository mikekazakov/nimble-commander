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

// WriteBuffer provides an intermediatery storage where a File can write into and CURL can read from afterwards
class WriteBuffer {
public:
    WriteBuffer();
    WriteBuffer(const WriteBuffer &) = delete;
    ~WriteBuffer();

    WriteBuffer &operator=(const WriteBuffer &) = delete;

    // Adds the specified bytes into the buffer
    void Write(const void *_mem, size_t _size);
    
    // Returns the amount of data stored in the buffer
    size_t Size() const noexcept;
    
    // Returns the amount of data fed into the read function out of the available size
    size_t Consumed() const noexcept;

    // Returns true if there's no available data to provide to the read function
    bool Exhausted() const noexcept;
        
    // Removes the portion of the buffer that has been written.
    // Consumed() will be 0 afterwards.
    void DiscardConsumed() noexcept;

    // Reads the data from the buffer into the specified target.
    static size_t Read(void *_dest, size_t _size, size_t _nmemb, void *_this);

private:
    void Grow(uint32_t _new_size);
    
    static constexpr uint32_t s_DefaultCapacity = 32768;
    uint8_t *m_Buf = nullptr;
    uint32_t m_Size = 0;
    uint32_t m_Consumed = 0; // amount of bytes fed to CURL
    uint32_t m_Capacity = 0;
};

/**
 * User data should be a pointer to std::string
 */
size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp);

std::shared_ptr<Directory> ParseListing(const char *_str);

int CURLErrorToVFSError(CURLcode _curle);

} // namespace nc::vfs::ftp
