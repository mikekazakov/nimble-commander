// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextWidthsCache.h"
#include <Utility/FontExtras.h>

namespace nc::panel::brief {

// it was deliberately chosen to use the most dumb method to purge the cache.
// assuming that one record on average taken about 100bytes, 10'000 would take around 1Mb of memory.
// the purge is executed after a significant delay, thus allowing NC to temporary cache a huge
// amount of width values in case of an extreme workload, e.g. browsing in temporary panel with a
// million entries inside.
static const auto g_MaxStrings = 10'000;
static const auto g_PurgeDelay = 20min;

TextWidthsCache::TextWidthsCache()
{
}

TextWidthsCache::~TextWidthsCache()
{
}

TextWidthsCache& TextWidthsCache::Instance()
{
    static const auto inst = new TextWidthsCache;
    return *inst;
}

vector<short> TextWidthsCache::Widths(const vector<reference_wrapper<const string>> &_strings,
                                      NSFont *_font )
{
    assert( _font != nullptr );
    auto &cache = ForFont(_font);

    vector<short> widths(_strings.size(), 0);
    vector<int> indx;
    vector<CFStringRef> cf_strings;

    LOCK_GUARD(cache.lock) {
        int index = 0;
        for( const auto &str: _strings ) {
            const auto it = cache.widthds.find(str.get());
            if( it != end(cache.widthds) ) {
                widths[index] = it->second;
            }
            else if( const auto cf_str = CFStringCreateWithUTF8StdString( str.get() ) ) {
                cf_strings.emplace_back(cf_str);
                indx.emplace_back(index);
            }
            ++index;
        }
    }
    
    if( !indx.empty() ) {
        PurgeIfNeeded(cache);
        const auto new_widthds = FontGeometryInfo::CalculateStringsWidths( cf_strings, _font );
        assert( new_widthds.size() == indx.size() );
        int index = 0;
        LOCK_GUARD(cache.lock) {
            for( auto w: new_widthds ) {
                widths[ indx[index] ] = w;
                cache.widthds[ _strings[ indx[index] ].get() ] = w;
                ++index;
            }
        }
        for( auto cf_str: cf_strings )
            CFRelease(cf_str);
    }
    
    return widths;
}

TextWidthsCache::Cache &TextWidthsCache::ForFont(NSFont *_font)
{
    char buf[1024];
    const auto name = _font.fontName.UTF8String;
    const auto size = (int)floor(_font.pointSize + 0.5);
    snprintf(buf, sizeof(buf), "%s%d", name, size);

    LOCK_GUARD(m_Lock) {
        return m_CachesPerFont[buf];
    }
}

void TextWidthsCache::PurgeIfNeeded(Cache &_cache)
{
    LOCK_GUARD(_cache.lock) {
        if( _cache.widthds.size() >= g_MaxStrings && !_cache.purge_scheduled ) {
            _cache.purge_scheduled = true;
            dispatch_to_background_after(g_PurgeDelay, [&]{
                Purge(_cache);
            });
        }
    }
}

void TextWidthsCache::Purge(Cache &_cache)
{
    LOCK_GUARD(_cache.lock) {
        _cache.widthds.clear();
    }
    _cache.purge_scheduled = false;
}

}
