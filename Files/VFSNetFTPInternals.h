//
//  VFSNetFTPInternals.h
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <curl/curl.h>
#import <string>
#import <deque>
#import <map>
#import <mutex>
#import <memory>
#import <vector>

#import "Common.h"
#import "VFSHost.h"
#import "VFSListing.h"

using namespace std;

namespace VFSNetFTP
{

static const uint64_t g_ListingOutdateLimit = 1000lu * 1000lu * 1000lu * 30lu; // 30 sec

struct CURLInstance
{
    ~CURLInstance()
    {
        if(curl)
        {
            curl_easy_cleanup(curl);
            curl = 0;
        }
    }
    
    CURL *curl = 0;
//    string last_cwd; // last path where this connection was at
    mutex call_lock;
};

struct Entry
{
    Entry(){}
    ~Entry()
    {
        if(cfname != 0)
        {
            CFRelease(cfname);
            cfname = 0;
        }
    }
    Entry(const Entry&) = delete;
    Entry(const Entry&&) = delete;
    void operator=(const Entry&) = delete;
    
    string      name;
    CFStringRef cfname = 0; // no allocations, pointing at name
    uint64_t    size   = 0;
    time_t      time   = 0;
    mode_t      mode   = 0;
    // links support in the future
    
    void ToStat(VFSStat &_stat) const
    {
        memset(&_stat, 0, sizeof(_stat));
        _stat.size = size;
        _stat.mode = mode;
        _stat.mtime.tv_sec = time;
        _stat.ctime.tv_sec = time;
        _stat.btime.tv_sec = time;
        _stat.atime.tv_sec = time;        
    }
};
    
struct Directory
{
    deque<Entry>            entries;
    shared_ptr<Directory>   parent_dir;
    uint64_t                snapshot_time = 0;
    
    
    inline bool IsOutdated() const
    {
        return GetTimeInNanoseconds() > snapshot_time + g_ListingOutdateLimit;
    }
    
    inline const Entry* EntryByName(string _name) const
    {
        auto i = find_if(begin(entries), end(entries), [&](auto &_e) { return _e.name == _name; });
        return i != end(entries) ? &(*i) : nullptr;
    }
};

class Cache
{
public:
    
    
    /**
     * Return nullptr if was not able to find directory.
     */
    shared_ptr<Directory> FindDirectory(const char *_path) const;
    
    shared_ptr<Directory> FindDirectory(const string &_path) const;
    
    /**
     * If directory at _path is already in cache - it will be overritten.
     */
    void InsertDirectory(const char *_path, shared_ptr<Directory> _dir);
    
    
    
private:
    map<string, shared_ptr<Directory>>  m_Directories; // "/Abra/Cadabra/" -> Directory
    mutable mutex                       m_CacheLock;
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