// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/CFString.h>
#include <unordered_map>
#include <string>
#include <Habanero/spinlock.h>

namespace nc::panel::brief {

class TextWidthsCache
{
public:
    static TextWidthsCache& Instance();

    std::vector<short> Widths( const std::vector<CFStringRef> &_strings, NSFont *_font );

private:
    struct CFStringHash {
        std::size_t operator()(const CFString &_string) const noexcept;
    };
    struct CFStringEqual {
        bool operator()(const CFString &_lhs, const CFString &_rhs) const noexcept;
    };
    struct Cache {
        std::unordered_map<CFString, short, CFStringHash, CFStringEqual> widths;
        spinlock lock;
        std::atomic_bool purge_scheduled{false};
    };
    
    TextWidthsCache();
    ~TextWidthsCache();
    Cache &ForFont(NSFont *_font);
    void PurgeIfNeeded(Cache &_cache);
    static void Purge(Cache &_cache);
    
    std::unordered_map<std::string, Cache> m_CachesPerFont;
    spinlock m_Lock;
};

}
