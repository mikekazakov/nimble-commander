//
//  VFSNetFTPInternals.h
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "3rd_party/built/include/curl/curl.h"
#import "Common.h"
#import "VFSHost.h"
#import "VFSListing.h"
#import "VFSNetFTPCache.h"

namespace VFSNetFTP
{

static const curl_ftpmethod g_CURLFTPMethod = /*CURLFTPMETHOD_DEFAULT*/ /*CURLFTPMETHOD_MULTICWD*/ CURLFTPMETHOD_SINGLECWD /*CURLFTPMETHOD_NOCWD*/;

struct CURLInstance
{
    ~CURLInstance()
    {
        if(curl)
        {
            curl_easy_cleanup(curl);
            curl = 0;
        }
        
        if(curlm)
            curl_multi_cleanup(curlm);
    }
    
    int RunningHandles()
    {
        int running_handles = 0;
        call_lock.lock();
        curl_multi_perform(curlm, &running_handles);
        call_lock.unlock();
        return running_handles;
    }
    
    template <typename T>
    inline CURLcode EasySetOpt(CURLoption _option, T _t) { return curl_easy_setopt(curl, _option, _t); }
    
    bool IsAttached() const { return attached; }
    CURLMcode Attach();
    CURLMcode Detach();
    CURLcode PerformMulti();
    
    CURL  *curl  = nullptr;
    CURLM *curlm = nullptr;
    bool attached = false;
//    string last_cwd; // last path where this connection was at
    mutex call_lock;
};
    
struct Buffer
{
    Buffer()
    {
        grow(default_capacity);
    }
    ~Buffer()
    {
        free(buf);
    }
    Buffer(const Buffer&) = delete;
    Buffer(const Buffer&&) = delete;
    void operator=(const Buffer&) = delete;
    
    void clear()
    {
        size = 0;
    }
    
    void add(const void *_mem, size_t _size)
    {
        if(capacity < size + _size)
            grow(size + (uint32_t)_size);
        
        memcpy(buf + size, _mem, _size);
        size += _size;
    }
    
    void grow(uint32_t _new_size)
    {
        buf = (uint8_t*) realloc(buf, capacity = (uint32_t)_new_size);
    }
    
    static size_t write_here_function(void *buffer, size_t size, size_t nmemb, void *userp)
    {
        Buffer *buf = (Buffer*) userp;
        buf->add(buffer, size*nmemb);
        return size*nmemb;
    }
    
//    static size_t write_data_bg(void *ptr, size_t size, size_t nmemb, void *data) {
    
    void discard(size_t _sz)
    {
        assert(_sz <= size);
        memmove(buf,
                buf + _sz,
                size - _sz);
        size = size - (uint32_t)_sz;
    }
    
    uint8_t              *buf = 0;
    static const uint32_t default_capacity = 32768;
    uint32_t              size = 0;
    uint32_t              capacity = 0;
};
    
struct WriteBuffer
{
    WriteBuffer()
    {
        grow(default_capacity);
    }
    ~WriteBuffer()
    {
        free(buf);
    }
    WriteBuffer(const WriteBuffer&) = delete;
    WriteBuffer(const WriteBuffer&&) = delete;
    void operator=(const WriteBuffer&) = delete;
    
    void clear()
    {
        size = 0;
    }
    
    void add(const void *_mem, size_t _size)
    {
        if(capacity < size + _size)
            grow(size + (uint32_t)_size);
        
        memcpy(buf + size, _mem, _size);
        size += _size;
    }
    
    void grow(uint32_t _new_size)
    {
        buf = (uint8_t*) realloc(buf, capacity = (uint32_t)_new_size);
    }
    
    static size_t read_from_function(void *ptr, size_t size, size_t nmemb, void *data)
    {
        WriteBuffer *buf = (WriteBuffer*) data;
        
        assert(buf->feed_size <= buf->size);
        
        size_t feed = size * nmemb;
        if(feed > buf->size - buf->feed_size)
            feed = buf->size - buf->feed_size;
        memcpy(ptr, buf->buf + buf->feed_size, feed);
        buf->feed_size += feed;
        
//        NSLog(@"Read request %lu, feed with %lu bytes", size*nmemb, feed);
        
        return feed;
    }
    
//    static size_t write_data_bg(void *ptr, size_t size, size_t nmemb, void *data) {
    
    void discard(size_t _sz)
    {
        assert(_sz <= size);
        memmove(buf,
                buf + _sz,
                size - _sz);
        size = size - (uint32_t)_sz;
    }
    
    uint8_t              *buf = 0;
    static const uint32_t default_capacity = 32768;
    uint32_t              size = 0;
    uint32_t              capacity = 0;
    uint32_t              feed_size = 0; // amount of bytes fed to CURL
};

class Listing : public VFSListing
{
public:
    Listing(shared_ptr<Directory> _dir,
            const char *_path,
            int _flags,
            shared_ptr<VFSHost> _host);
    
    virtual VFSListingItem& At(size_t _position) override { return m_Items[_position];};
    virtual const VFSListingItem& At(size_t _position) const override { return m_Items[_position];};
    virtual int Count() const override { return (int)m_Items.size();}
        
private:
    vector<VFSGenericListingItem> m_Items;
    shared_ptr<Directory>         m_Directory; // hold a link to dir to ensure that it will be alive
};
    
    
//int function(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow);
    
/**
 * User data should be a pointer to block of type (bool(^)()), may be nullptr.
 * Like this: ((__bridge void *)_cancel_checher).
 */
int RequestCancelCallback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow);
void SetupRequestCancelCallback(CURL *_curl, bool (^_cancel_checker)());
void ClearRequestCancelCallback(CURL *_curl);
    
/**
 * User data should be a pointer to std::string
 */
size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp);
 
shared_ptr<Directory> ParseListing(const char *_str);
    
}