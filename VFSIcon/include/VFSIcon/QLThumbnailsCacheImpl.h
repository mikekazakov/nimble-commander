// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "QLThumbnailsCache.h"
#include <Cocoa/Cocoa.h>
#include <Habanero/LRUCache.h>
#include <Habanero/spinlock.h>
#include <Habanero/intrusive_ptr.h>
#include <string>
#include <atomic>
#include <optional>

namespace nc::vfsicon {

class QLThumbnailsCacheImpl : public QLThumbnailsCache 
{
public:
    QLThumbnailsCacheImpl();
    ~QLThumbnailsCacheImpl();
    
    NSImage *ThumbnailIfHas(const std::string &_filename, int _px_size) override;
    
    NSImage *ProduceThumbnail(const std::string &_filename, int _px_size) override;

    NSImage *ProduceThumbnail(const std::string &_filename,
                              int _px_size,
                              const FileStateHint& _hint) override;
    
private:
    enum { m_CacheSize = 4096 };
    
    /**
     * This string_view/string abomination is used to mitigate the lack of heterogenious
     * lookup in unordered_map and to remove allocation/deletions when performing a shallow lookup.
     */
    struct Key
    {
        static inline struct no_ownership_tag {} no_ownership;
        Key();
        Key(const std::string& _path, int _px_size);
        Key(std::string_view _path, int _px_size, no_ownership_tag);
        Key(const Key&);
        Key(Key&&) noexcept;
        Key &operator=(const Key& _rhs);
        Key &operator=(Key&& _rhs) noexcept = default;
        bool operator==(const Key& _rhs) const noexcept;
        bool operator!=(const Key& _rhs) const noexcept;
        std::string_view path;
        size_t hash = 0;        
        int    px_size = 16;
        std::string path_storage;        
    };
    struct KeyHash 
    {
        size_t operator()(const Key& c) const noexcept;
    };
    
    struct Info : hbn::intrusive_ref_counter<Info>
    {
        NSImage    *image = nil; // may be nil - it means that QL can't produce thumbnail for this file
        uint64_t    file_size = 0;
        uint64_t    mtime = 0;
        std::atomic_flag is_in_work = {false}; // item is currenly updating its image
    };
    
    using Container = base::LRUCache<Key, hbn::intrusive_ptr<Info>, m_CacheSize, KeyHash>;

    NSImage *Produce(const std::string &_filename,
                     int _px_size,
                     const std::optional<FileStateHint> &_hint);
    static void CheckCacheAndUpdateIfNeeded(const std::string &_filename,
                                            int _px_size,
                                            Info &_info,
                                            const std::optional<FileStateHint> &_hint);
    static void ProduceNew(const std::string &_filename,
                           int _px_size,
                           Info &_info);    

    Container m_Items;
    spinlock  m_ItemsLock;    
};

}
