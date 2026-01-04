// Copyright (C) 2018-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFSBundleIconsCache.h"
#include <Base/LRUCache.h>
#include <Base/spinlock.h>

namespace nc::vfsicon {

class VFSBundleIconsCacheImpl : public VFSBundleIconsCache
{
public:
    VFSBundleIconsCacheImpl();
    ~VFSBundleIconsCacheImpl() override;

    NSImage *IconIfHas(const std::string &_file_path, VFSHost &_host) override;

    NSImage *ProduceIcon(const std::string &_file_path, VFSHost &_host) override;

private:
    // this is a lazy and far from ideal implementation
    // it cheats in several ways:
    // - it uses VFSHost's verbose path to make a unique path identifier
    // - it pretends that file do not change on VFSes
    // also, it's pretty inefficient in dealing with strings
    static constexpr size_t m_CacheSize = 128;
    using Container = base::LRUCache<std::string, NSImage *, m_CacheSize>;

    static std::string MakeKey(const std::string &_file_path, VFSHost &_host);
    static NSImage *ProduceBundleIcon(const std::string &_path, VFSHost &_host);
    static NSDictionary *ReadDictionary(const std::string &_path, VFSHost &_host);
    static NSData *ToTempNSData(std::span<const uint8_t> _data);
    static NSImage *ReadImageFromFile(const std::string &_path, VFSHost &_host);
    static std::expected<std::vector<uint8_t>, Error> ReadEntireFile(const std::string &_path, VFSHost &_host);

    Container m_Icons;
    mutable spinlock m_Lock;
};

} // namespace nc::vfsicon
