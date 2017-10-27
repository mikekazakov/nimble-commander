// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QLVFSThumbnailsCache.h"

static const nanoseconds g_PurgeDelay = 1min;

QLVFSThumbnailsCache &QLVFSThumbnailsCache::Instance() noexcept
{
    static QLVFSThumbnailsCache *inst = new QLVFSThumbnailsCache; // never delete
    return *inst;
}

pair<bool, NSImage*> QLVFSThumbnailsCache::Get(const string& _path, const VFSHostPtr &_host)
{
    lock_guard<mutex> lock(m_Lock);
    
    auto db = find_if(begin(m_Caches), end(m_Caches), [&](auto &_) { return _.host_raw == _host.get(); });
    if(db == end(m_Caches))
        return make_pair(false, nil);
  
    auto img = db->images.find(_path);
    if(img == end(db->images))
        return make_pair(false, nil);
    
    return make_pair(true, img->second);
}

void QLVFSThumbnailsCache::Put(const string& _path, const VFSHostPtr &_host, NSImage *_img)
{
    lock_guard<mutex> lock(m_Lock);
    
    auto db_it = find_if(begin(m_Caches), end(m_Caches), [&](auto &_) { return _.host_raw == _host.get(); });
    Cache *cache;
    if(db_it != end(m_Caches))
        cache = &(*db_it);
    else {
        m_Caches.emplace_front();
        cache = &m_Caches.front();
        cache->host_weak = _host;
        cache->host_raw  = _host.get();
        
        if(!m_PurgeScheduled) {
            m_PurgeScheduled = true;
            dispatch_after(g_PurgeDelay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), [=]{
                Purge();
            });
        }
    }
    
    cache->images[_path] = _img;
}

void QLVFSThumbnailsCache::Purge()
{
    assert(m_PurgeScheduled);
    lock_guard<mutex> lock(m_Lock);
    m_Caches.remove_if([](auto &_t) { return _t.host_weak.expired(); });

    if(m_Caches.empty())
        m_PurgeScheduled = false;
    else
        dispatch_after(g_PurgeDelay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), [=]{
            Purge();
        });
}
