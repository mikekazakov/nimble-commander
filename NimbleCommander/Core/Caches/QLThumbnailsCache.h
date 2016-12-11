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
    NSImageRep *ThumbnailIfHas(const string &_filename);
    
    /**
     * Will check for a presence of a thumbnail for _filename in cache.
     * If it is, will check if file wasn't changed - in this case just return a thumbnail that we have.
     * If file was changed or there's no thumbnail for this file - produce it with BuildRep() and return result.
     */
    NSImageRep *ProduceThumbnail(const string &_filename, CGSize _size);
    
private:
    static NSImageRep *BuildRep(const string &_filename, CGSize _size);
    
    enum { m_CacheSize = 4096 };
    
    struct Info
    {
        uint64_t    file_size;
        uint64_t    mtime;
        NSImageRep *image;      // may be nil - it means that QL can't produce thumbnail for this file
        CGSize      image_size; // currently not accouning when deciding if cache is outdated
        atomic_flag is_in_work = {false}; // item is currenly updating it's image
    };
    using Container = map<string, shared_ptr<Info>>;
    Container                           m_Items;
    shared_timed_mutex                  m_ItemsLock;
    deque<Container::iterator>          m_MRU;
    mutex                               m_MRULock;    
};
