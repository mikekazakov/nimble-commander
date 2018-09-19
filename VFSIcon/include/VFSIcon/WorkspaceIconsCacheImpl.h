// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include "WorkspaceIconsCache.h"
#include <Habanero/LRUCache.h>
#include <Habanero/spinlock.h>
#include <Habanero/intrusive_ptr.h>
#include <Cocoa/Cocoa.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wignored-qualifiers" // working around __strong and gmock

namespace nc::vfsicon {

namespace detail {

struct WorkspaceIconsCacheImplBase {
    struct FileStateHint {
        uint64_t    size = 0;
        uint64_t    mtime = 0;
        mode_t      mode = 0;
    };    
    struct FileStateReader {
        virtual ~FileStateReader() = default;
        virtual std::optional<FileStateHint>
            ReadState(const std::string &_file_path) = 0;        
    };
    struct FileStateReaderImpl final : FileStateReader {
        std::optional<FileStateHint>
            ReadState(const std::string &_file_path) override;
        static FileStateReaderImpl instance;
    };
    struct IconBuilder {
        virtual ~IconBuilder() = default;
        virtual NSImage * __strong Build(const std::string &_file_path) = 0;        
    };
    struct IconBuilderImpl final : IconBuilder {
        NSImage * __strong Build(const std::string &_file_path) override;
        static IconBuilderImpl instance;
    };
};

}

class WorkspaceIconsCacheImpl final :
    public WorkspaceIconsCache,
    public detail::WorkspaceIconsCacheImplBase
{
public:
    
    WorkspaceIconsCacheImpl(FileStateReader &_file_state_reader = FileStateReaderImpl::instance,
                            IconBuilder &_icon_builder = IconBuilderImpl::instance);
    ~WorkspaceIconsCacheImpl();

    NSImage *IconIfHas(const std::string &_file_path) override;

    NSImage *ProduceIcon(const std::string &_file_path) override;
        
    static int CacheMaxSize() noexcept { return m_CacheSize; }
    
private:
    enum { m_CacheSize = 4096 };
    
    struct Info : hbn::intrusive_ref_counter<Info>
    {
        uint64_t    file_size = 0;
        uint64_t    mtime = 0;
        mode_t      mode = 0;
        // 'image' may be nil, it means that Workspace can't produce icon for this file.
        NSImage    *image = nil; 
        std::atomic_flag is_in_work = {false}; // item is currenly updating its image        
    };
    
    using Container = hbn::LRUCache<std::string, hbn::intrusive_ptr<Info>, m_CacheSize>;    

    NSImage *Produce(const std::string &_file_path,
                     std::optional<FileStateHint> _state_hint);    
    
    void UpdateIfNeeded(const std::string &_file_path,
                        Info &_info);
    void ProduceNew(const std::string &_file_path, Info &_info);
    
    Container m_Items;
    spinlock m_ItemsLock;
    FileStateReader &m_FileStateReader;    
    IconBuilder &m_IconBuilder;
};

}

#pragma clang diagnostic pop
