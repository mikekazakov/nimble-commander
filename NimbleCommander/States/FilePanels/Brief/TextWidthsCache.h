// Copyright (C) 2017-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Habanero/CFString.h>
#include <Habanero/RobinHoodUtil.h>
#include <unordered_map>
#include <string>
#include <Habanero/spinlock.h>
#include <robin_hood.h>

namespace nc::panel::brief {

class TextWidthsCache
{
public:
    static TextWidthsCache& Instance();

    std::vector<unsigned short> Widths( const std::vector<CFStringRef> &_strings, NSFont *_font );

private:
    struct CFStringHash {
        std::size_t operator()(const CFString &_string) const noexcept;
    };
    struct CFStringEqual {
        bool operator()(const CFString &_lhs, const CFString &_rhs) const noexcept;
    };
    struct Cache {
        // TODO: make this RH.
        // TODO: Make this a transparent lookup
        std::unordered_map<CFString, unsigned short, CFStringHash, CFStringEqual> widths;
        spinlock lock;
        std::atomic_bool purge_scheduled{false};
    };
    using CachesPerFontT = robin_hood::unordered_node_map<std::string,
        Cache, RHTransparentStringHashEqual, RHTransparentStringHashEqual>;
    
    TextWidthsCache();
    ~TextWidthsCache();
    Cache &ForFont(NSFont *_font);
    void PurgeIfNeeded(Cache &_cache);
    static void Purge(Cache &_cache);
        
    CachesPerFontT m_CachesPerFont;
    spinlock m_Lock;
};

}
