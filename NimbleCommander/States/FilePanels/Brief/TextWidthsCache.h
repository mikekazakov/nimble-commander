// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/CFString.h>

namespace nc::panel::brief {

class TextWidthsCache
{
public:
    static TextWidthsCache& Instance();

    vector<short> Widths( const vector<CFStringRef> &_strings, NSFont *_font );

private:
    struct CFStringHash {
        std::size_t operator()(const CFString &_string) const noexcept;
    };
    struct CFStringEqual {
        bool operator()(const CFString &_lhs, const CFString &_rhs) const noexcept;
    };
    struct Cache {
        unordered_map<CFString, short, CFStringHash, CFStringEqual> widths;
        spinlock lock;
        atomic_bool purge_scheduled{false};
    };
    
    TextWidthsCache();
    ~TextWidthsCache();
    Cache &ForFont(NSFont *_font);
    void PurgeIfNeeded(Cache &_cache);
    static void Purge(Cache &_cache);
    
    unordered_map<string, Cache> m_CachesPerFont;
    spinlock m_Lock;
};

}
