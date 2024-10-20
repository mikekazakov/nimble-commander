// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Base/CFPtr.h>
#include <Base/UnorderedUtil.h>
#include <string>
#include <mutex>
#include <span>
#include <atomic>

namespace nc::panel {

// This class provides a caching facility to get pixel widths of strings, presumably filenames.
// Under the hood it uses nc::utility::FontGeometryInfo::CalculateStringsWidths()
class TextWidthsCache
{
public:
    static TextWidthsCache &Instance();

    std::vector<unsigned short> Widths(std::span<const CFStringRef> _strings, NSFont *_font);

private:
    struct CFStringHashEqual {
        using is_transparent = void;

        // hashes
        size_t operator()(const base::CFPtr<CFStringRef> &_string) const noexcept;
        size_t operator()(CFStringRef _string) const noexcept;

        // equality
        bool operator()(const base::CFPtr<CFStringRef> &_lhs, const base::CFPtr<CFStringRef> &_rhs) const noexcept;
        bool operator()(const base::CFPtr<CFStringRef> &_lhs, CFStringRef _rhs) const noexcept;
        bool operator()(CFStringRef _lhs, const base::CFPtr<CFStringRef> &_rhs) const noexcept;
        bool operator()(CFStringRef _lhs, CFStringRef _rhs) const noexcept;
    };
    struct Cache {
        using WidthsT = ankerl::unordered_dense::
            map<base::CFPtr<CFStringRef>, unsigned short, CFStringHashEqual, CFStringHashEqual>;
        WidthsT widths;
        std::mutex lock;
        std::atomic_bool purge_scheduled{false};
    };
    using CachesPerFontT =
        ankerl::unordered_dense::segmented_map<std::string, Cache, UnorderedStringHashEqual, UnorderedStringHashEqual>;

    TextWidthsCache();
    ~TextWidthsCache();
    Cache &ForFont(NSFont *_font);
    static void PurgeIfNeeded(Cache &_cache);
    static void Purge(Cache &_cache);

    CachesPerFontT m_CachesPerFont;
    std::mutex m_Lock;
};

} // namespace nc::panel
