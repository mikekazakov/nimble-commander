// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once



// need to fiddle with shared_mutex availability on 10.11, so using this hammer.
#define _LIBCPP_DISABLE_AVAILABILITY 1


#include <string>
#include <map>
#include <stdint.h>
#include <mutex>
#include <shared_mutex>
#include <deque>
#include "WorkspaceIconsCache.h"

@class NSImage;

namespace nc::utility {

class WorkspaceIconsCacheImpl : public WorkspaceIconsCache 
{
public:
    WorkspaceIconsCacheImpl();
    ~WorkspaceIconsCacheImpl();

    NSImage *IconIfHas(const std::string &_filename) override;

    NSImage *ProduceIcon(const std::string &_filename) override;
private:
    
    enum { m_CacheSize = 4096 };
    
    struct Info
    {
        uint64_t    file_size;
        uint64_t    mtime;
        mode_t	 	mode;
        NSImage *image;      // may be nil - it means that Workspace can't produce icon for this file
    };
    std::map<std::string, Info>                   m_Items;
    std::shared_timed_mutex                  m_ItemsLock;
    std::deque<typename std::map<std::string, Info>::iterator>  m_MRU;
    std::mutex                               m_MRULock;
};

}


