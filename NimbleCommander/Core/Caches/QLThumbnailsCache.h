//
//  QLThumbnailsCache.h
//  Files
//
//  Created by Michael G. Kazakov on 24.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

class QLThumbnailsCache
{
public:
    static QLThumbnailsCache &Instance();
    
    /**
     * Returns cached QLThunmbnail for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     */
    NSImage *ThumbnailIfHas(const string &_filename, int _px_size);
    
    /**
     * Will check for a presence of a thumbnail for _filename in cache.
     * If it is, will check if file wasn't changed - in this case just return a thumbnail that we have.
     * If file was changed or there's no thumbnail for this file - produce it with BuildRep() and return result.
     */
    NSImage *ProduceThumbnail(const string &_filename, int _px_size);
    
private:
    
    enum { m_CacheSize = 4096 };
    
    struct Key
    {
        Key(const string& _p, int _s) noexcept : path(_p), px_size(_s){};
        bool operator<(const Key& _rhs) const noexcept {
            return path < _rhs.path ? true : (px_size < _rhs.px_size);
        }
        bool operator==(const Key& _rhs) const noexcept {
            return path == _rhs.path && px_size == _rhs.px_size;
        }
        string path;
        int    px_size;
    };
    
    struct Info
    {
        NSImage *image;      // may be nil - it means that QL can't produce thumbnail for this file
        uint64_t    file_size;
        uint64_t    mtime;
        atomic_flag is_in_work = {false}; // item is currenly updating it's image
    };
    using Container = map<Key, shared_ptr<Info>>;
    Container                           m_Items;
    shared_timed_mutex                  m_ItemsLock;
    deque<Container::iterator>          m_MRU;
    spinlock                            m_MRULock;
};
