//
//  WorkspaceIconsCache.h
//  Files
//
//  Created by Michael G. Kazakov on 25.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

class WorkspaceIconsCache
{
public:
    static WorkspaceIconsCache& Instance();
    
    /**
     * Returns cached Workspace Icon for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     */
    NSImageRep *IconIfHas(const string &_filename);
    
    NSImageRep *ProduceIcon(const string &_filename, CGSize _size);
    
    static NSImageRep *BuildRep(const string &_filename, CGSize _size);
private:
    
    enum { m_CacheSize = 4096 };
    
    struct Info
    {
        uint64_t    file_size;
        uint64_t    mtime;
        mode_t	 	mode;
        NSImageRep *image;      // may be nil - it means that Workspace can't produce icon for this file
        CGSize      image_size; // currently not accouning when deciding if cache is outdated
    };
    map<string, Info>                   m_Items;
    shared_timed_mutex                  m_ItemsLock;
    deque<map<string, Info>::iterator>  m_MRU;
    mutex                               m_MRULock;
};