// Copyright (C) 2017-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextWidthsCache.h"
#include <Utility/FontExtras.h>
#include <Habanero/dispatch_cpp.h>
#include <charconv>
#include <array>
#include <boost/container/pmr/vector.hpp>                    // TODO: remove as soon as libc++ gets pmr!!!
#include <boost/container/pmr/monotonic_buffer_resource.hpp> // TODO: remove as soon as libc++ gets pmr!!!

namespace nc::panel {

using namespace std::literals;
using nc::utility::FontGeometryInfo;

// it was deliberately chosen to use the most dumb method to purge the cache.
// assuming that one record on average taken about 100bytes, 10'000 would take around 1Mb of memory.
// the purge is executed after a significant delay, thus allowing NC to temporary cache a huge
// amount of width values in case of an extreme workload, e.g. browsing in temporary panel with a
// million entries inside.
static const auto g_MaxStrings = 10'000;
static const auto g_PurgeDelay = 20min;

TextWidthsCache::TextWidthsCache() = default;

TextWidthsCache::~TextWidthsCache() = default;

TextWidthsCache &TextWidthsCache::Instance()
{
    [[clang::no_destroy]] static TextWidthsCache inst;
    return inst;
}

std::vector<unsigned short> TextWidthsCache::Widths(std::span<const CFStringRef> _strings, NSFont *_font)
{
    assert(_font != nullptr);
    auto &cache = ForFont(_font);

    // the result widths to return
    std::vector<unsigned short> widths(_strings.size(), 0);

    // store the temp data on stack whether possible
    std::array<char, 16384> mem_buffer;
    boost::container::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
    boost::container::pmr::vector<size_t> unknown_strings_indices(&mem_resource);
    boost::container::pmr::vector<CFStringRef> unknown_strings(&mem_resource);

    {
        auto lock = std::lock_guard{cache.lock};
        for( size_t index = 0; index != _strings.size(); ++index ) {
            const auto string = _strings[index];
            const auto it = cache.widths.find(string);
            if( it != cache.widths.end() ) {
                widths[index] = it->second;
            }
            else {
                unknown_strings.emplace_back(string);
                unknown_strings_indices.emplace_back(index);
            }
        }
    }

    if( !unknown_strings_indices.empty() ) {
        // Something is missing in the cache - need to actually perform some calculations
        auto new_widths = FontGeometryInfo::CalculateStringsWidths(unknown_strings, _font);
        const auto new_widths_sz = new_widths.size();
        assert(new_widths_sz == unknown_strings_indices.size());

        {
            // insert the new widths into the cache
            auto lock = std::lock_guard{cache.lock};
            for( size_t index = 0; index < new_widths_sz; ++index ) {
                const auto src_index = unknown_strings_indices[index];
                assert(src_index < _strings.size());
                CFStringRef src_string = _strings[src_index];
                assert(new_widths[index] > 0 || CFStringGetLength(_strings[src_index]) == 0);
                cache.widths[base::CFPtr<CFStringRef>(src_string)] = new_widths[index];
            }
        }

        // merge the newly calculated data into the widths to be returned
        if( unknown_strings_indices.size() == _strings.size() ) {
            // we're building the entire set => can just snatch the result vector without copying by element by element
            widths = std::move(new_widths);
        }
        else {
            // fill the unknowns with the newly calculated data
            for( size_t index = 0; index < new_widths_sz; ++index ) {
                const auto src_index = unknown_strings_indices[index];
                assert(src_index < widths.size());
                widths[src_index] = new_widths[index];
            }
        }

        // If we're getting too large - schedule a future trimming
        PurgeIfNeeded(cache);
    }

    return widths;
}

TextWidthsCache::Cache &TextWidthsCache::ForFont(NSFont *_font)
{
    // compose e.g. "12Times New Roman Regular" as a key
    char buf[1024];
    const auto name = _font.fontName.UTF8String;
    const auto font_size = static_cast<int>(std::floor(_font.pointSize + 0.5));
    const auto rc = std::to_chars(std::begin(buf), std::end(buf), font_size);
    strcpy(rc.ptr, name);
    const std::string_view key(buf);

    auto lock = std::lock_guard{m_Lock};
    if( auto it = m_CachesPerFont.find(key); it != m_CachesPerFont.end() ) {
        return it->second;
    }
    else {
        return m_CachesPerFont[buf];
    }
}

void TextWidthsCache::PurgeIfNeeded(Cache &_cache)
{
    auto lock = std::lock_guard{_cache.lock};
    if( _cache.widths.size() >= g_MaxStrings && !_cache.purge_scheduled ) {
        _cache.purge_scheduled = true;
        dispatch_to_background_after(g_PurgeDelay, [&] { Purge(_cache); });
    }
}

void TextWidthsCache::Purge(Cache &_cache)
{
    {
        auto lock = std::lock_guard{_cache.lock};
        _cache.widths.clear();
    }
    _cache.purge_scheduled = false;
}

size_t TextWidthsCache::CFStringHashEqual::operator()(const base::CFPtr<CFStringRef> &_string) const noexcept
{
    return (*this)(_string.get());
}

size_t TextWidthsCache::CFStringHashEqual::operator()(CFStringRef _string) const noexcept
{
    assert(_string != nil);
    return CFHash(_string);
}

bool TextWidthsCache::CFStringHashEqual::operator()(const base::CFPtr<CFStringRef> &_lhs,
                                                    const base::CFPtr<CFStringRef> &_rhs) const noexcept
{
    return (*this)(_lhs.get(), _rhs.get());
}

bool TextWidthsCache::CFStringHashEqual::operator()(const base::CFPtr<CFStringRef> &_lhs,
                                                    CFStringRef _rhs) const noexcept
{
    return (*this)(_lhs.get(), _rhs);
}

bool TextWidthsCache::CFStringHashEqual::operator()(CFStringRef _lhs,
                                                    const base::CFPtr<CFStringRef> &_rhs) const noexcept
{
    return (*this)(_lhs, _rhs.get());
}

bool TextWidthsCache::CFStringHashEqual::operator()(CFStringRef _lhs, CFStringRef _rhs) const noexcept
{
    return (_lhs == _rhs) || (CFStringCompare(_lhs, _rhs, 0) == kCFCompareEqualTo);
}

} // namespace nc::panel
