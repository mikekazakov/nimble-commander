// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "QLVFSThumbnailsCache.h"
#include <Utility/BriefOnDiskStorage.h>
#include <Habanero/LRUCache.h>
#include <Habanero/spinlock.h>

namespace nc::vfsicon {
    
class QLVFSThumbnailsCacheImpl : public QLVFSThumbnailsCache
{
public:
    QLVFSThumbnailsCacheImpl(const std::shared_ptr<utility::BriefOnDiskStorage> &_temp_storage);
    ~QLVFSThumbnailsCacheImpl();
    
    NSImage *ThumbnailIfHas(const std::string &_file_path,
                            VFSHost &_host,
                            int _px_size) override;    
    
    NSImage * ProduceThumbnail(const std::string &_file_path,
                               VFSHost &_host,
                               int _px_size) override;

private:
    // this is a lazy and far from ideal implementation
    // it cheats in several ways:
    // - it uses VFSHost's verbose path to make a unique path identifier
    // - it pretends that file do not change on VFSes
    // also, it's pretty inefficient in dealing with strings 

    enum { m_CacheSize = 1024 };    
    using Container = base::LRUCache<std::string, NSImage*, m_CacheSize>;    

    NSImage *ProduceThumbnail(const std::string &_path,
                              const std::string &_ext,
                              VFSHost &_host,
                              CGSize _sz);
    static std::string MakeKey(const std::string &_file_path, VFSHost &_host, int _px_size);

    Container m_Thumbnails;
    mutable spinlock m_Lock;
    std::shared_ptr<utility::BriefOnDiskStorage> m_TempStorage;
};
    
}
