// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class WorkspaceIconsCache
{
public:
    static WorkspaceIconsCache& Instance();
    
    /**
     * Returns cached Workspace Icon for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     */
    NSImage *IconIfHas(const string &_filename);

    NSImage *ProduceIcon(const string &_filename);
private:
    
    enum { m_CacheSize = 4096 };
    
    struct Info
    {
        uint64_t    file_size;
        uint64_t    mtime;
        mode_t	 	mode;
        NSImage *image;      // may be nil - it means that Workspace can't produce icon for this file
    };
    map<string, Info>                   m_Items;
    shared_timed_mutex                  m_ItemsLock;
    deque<map<string, Info>::iterator>  m_MRU;
    mutex                               m_MRULock;
};
