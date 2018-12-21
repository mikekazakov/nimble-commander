// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextWidthsCache.h"
#include <Utility/FontExtras.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::panel::brief {

using namespace std::literals;
using nc::utility::FontGeometryInfo;

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

std::vector<short> TextWidthsCache::Widths( const std::vector<CFStringRef> &_strings,
                                           NSFont *_font )
{
    assert( _font != nullptr );
    auto &cache = ForFont(_font);
    
    std::vector<short> widths(_strings.size(), 0);
    std::vector<int> result_indices;
    std::vector<CFStringRef> cf_strings;

    LOCK_GUARD(cache.lock) {
        int result_index = 0;
        for( const auto string: _strings ) {
            const auto it = cache.widths.find( CFString{string} );
            if( it != end(cache.widths) ) {
                widths[result_index] = it->second;
            }
            else {
                cf_strings.emplace_back(string);
                result_indices.emplace_back(result_index);
            }
            
            ++result_index;
        }
    }
    
    if( !result_indices.empty() ) {
        PurgeIfNeeded(cache);
        auto new_widths = FontGeometryInfo::CalculateStringsWidths( cf_strings, _font );
        assert( new_widths.size() == result_indices.size() );
        if( result_indices.size() == _strings.size() ) {
            // we're building the entire set => can just snatch the result vector without copying
            LOCK_GUARD(cache.lock) {
                int index = 0;
                for( auto w: new_widths ) {
                    const auto result_index = result_indices[index]; 
                    cache.widths[ CFString{_strings[result_index]} ] = w;
                    ++index;
                }
            }
            widths = std::move(new_widths);
        }
        else {
            LOCK_GUARD(cache.lock) {
                int index = 0;
                for( auto w: new_widths ) {
                    const auto result_index = result_indices[index]; 
                    widths[ result_index ] = w;
                    cache.widths[ CFString{_strings[result_index]} ] = w;
                    ++index;
                }
            }    
        }
    }
    return widths;
}

TextWidthsCache::Cache &TextWidthsCache::ForFont(NSFont *_font)
{
    char buf[1024];
    const auto name = _font.fontName.UTF8String;
    const auto size = (int)std::floor(_font.pointSize + 0.5);
    snprintf(buf, sizeof(buf), "%s%d", name, size);

    LOCK_GUARD(m_Lock) {
        return m_CachesPerFont[buf];
    }
}

void TextWidthsCache::PurgeIfNeeded(Cache &_cache)
{
    LOCK_GUARD(_cache.lock) {
        if( _cache.widths.size() >= g_MaxStrings && !_cache.purge_scheduled ) {
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
        _cache.widths.clear();
    }
    _cache.purge_scheduled = false;
}

std::size_t TextWidthsCache::CFStringHash::operator()(const CFString & _string) const noexcept
{
    return CFHash(*_string);
}
    
bool TextWidthsCache::CFStringEqual::operator()(const CFString & _lhs,
                                                const CFString & _rhs) const noexcept
{ 
    return *_lhs == *_rhs || CFStringCompare(*_lhs, *_rhs, 0) == kCFCompareEqualTo;
}
    
}
