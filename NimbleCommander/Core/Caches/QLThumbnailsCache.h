// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/LRUCache.h>

namespace nc::core {

class QLThumbnailsCache
{
public:
    static QLThumbnailsCache &Instance();
    
    /**
     * Returns cached QLThunmbnail for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     * May return nil.
     */
    NSImage *ThumbnailIfHas(const string &_filename, int _px_size);
    
    /**
     * Will check for a presence of a thumbnail for _filename in cache.
     * If it is, will check if file wasn't changed - in this case just return a thumbnail that we have.
     * If file was changed or there's no thumbnail for this file - produce it with BuildRep() and return result.
     * May return nil.
     */
    NSImage *ProduceThumbnail(const string &_filename, int _px_size);
    
private:
    enum { m_CacheSize = 4096 };
    
    struct Key
    {
        Key();
        Key(const string& _p, int _s);
        bool operator==(const Key& _rhs) const noexcept;
        string path;
        int    px_size = 16;
        size_t hash = 0;
    };
    struct KeyHash 
    {
        size_t operator()(const Key& c) const noexcept;
    };
    
    struct Info
    {
        NSImage    *image = nil; // may be nil - it means that QL can't produce thumbnail for this file
        uint64_t    file_size = 0;
        uint64_t    mtime = 0;
        atomic_flag is_in_work = {false}; // item is currenly updating its image
    };
    
    using Container = hbn::LRUCache<Key, shared_ptr<Info>, m_CacheSize, KeyHash>;

    static void CheckCacheAndUpdateIfNeeded(const string &_filename,
                                            int _px_size,
                                            Info &_info);
    static void ProduceNew(const string &_filename,
                           int _px_size,
                           Info &_info);    

    Container m_Items;
    spinlock  m_ItemsLock;    
};

}
