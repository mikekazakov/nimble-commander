// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel::brief {

class TextWidthsCache
{
public:
    static TextWidthsCache& Instance();

    vector<short> Widths( const vector<reference_wrapper<const string>> &_strings, NSFont *_font );

private:
    struct Cache {
        unordered_map<string, short> widthds;
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
