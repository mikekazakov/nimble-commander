// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <VFS/Host.h>
#include <vector>
#include <cstddef>
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

// ...
class ReadBuffer {
public:
    
    // Returns the amount of data stored in the buffer
    size_t Size() const noexcept;
    
    // ...
    const void *Data() const noexcept;

    // ...
    void Clear();
    
    // ...
    static size_t Write(const void *_src, size_t _size, size_t _nmemb, void *_this);

    // ...
    void Discard(size_t _sz);

private:
    std::vector<std::byte> m_Buf;
};

// WriteBuffer provides an intermediatery storage where a File can write into and CURL can read from afterwards
class WriteBuffer {
public:
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
    size_t DoRead(void *_dest, size_t _size, size_t _nmemb);
    
    std::vector<std::byte> m_Buf;
    size_t m_Consumed = 0; // amount of bytes fed to CURL
};

/**
 * User data should be a pointer to std::string
 */
size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp);

std::shared_ptr<Directory> ParseListing(const char *_str);

int CURLErrorToVFSError(CURLcode _curle);

} // namespace nc::vfs::ftp
