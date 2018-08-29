// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include "WorkspaceIconsCache.h"
#include <Habanero/LRUCache.h>
#include <Habanero/spinlock.h>
#include <Cocoa/Cocoa.h>

namespace nc::utility {

class WorkspaceIconsCacheImpl : public WorkspaceIconsCache 
{
public:
    WorkspaceIconsCacheImpl();
    ~WorkspaceIconsCacheImpl();

    NSImage *IconIfHas(const std::string &_file_path) override;

    NSImage *ProduceIcon(const std::string &_file_path) override;
    
    NSImage *ProduceIcon(const std::string &_file_path,
                         const FileStateHint &_state_hint) override;
    
private:
    enum { m_CacheSize = 4096 };
    
    struct Info
    {
        uint64_t    file_size = 0;
        uint64_t    mtime = 0;
        mode_t      mode = 0;
        // 'image' may be nil, it means that Workspace can't produce icon for this file.
        NSImage    *image = nil; 
        std::atomic_flag is_in_work = {false}; // item is currenly updating its image        
    };
    
    using Container = hbn::LRUCache<std::string, std::shared_ptr<Info>, m_CacheSize>;    

    NSImage *Produce(const std::string &_file_path,
                     std::optional<FileStateHint> _state_hint);    
    
    void UpdateIfNeeded(const std::string &_file_path,
                        const std::optional<FileStateHint> &_state_hint,
                        Info &_info);
    void ProduceNew(const std::string &_file_path, Info &_info);
    
    Container m_Items;
    spinlock m_ItemsLock;
};

}
