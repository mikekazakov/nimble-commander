// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSDeclarations.h>
#include <CoreFoundation/CoreFoundation.h>

#include "PanelDataItemVolatileData.h"

#include <compare>
#include <optional>

namespace nc::panel::data {

struct TextualFilter {
    enum Where : int8_t // persistancy-bound values, don't change it
    {
        Anywhere = 0,
        Beginning = 1,
        Ending = 2, // handling extensions somehow
        BeginningOrEnding = 3,
        Fuzzy = 4
    };

    NSString *text;
    Where type = Where::Anywhere;

    // will not apply filter on dot-dot entries
    bool ignore_dot_dot : 1 = true;

    // if true then PanelData will automatically set text to nil on Load method call
    bool clear_on_new_listing : 1 = false;

    // option for PanelData to mark QS hightlight
    bool hightlight_results : 1 = true;

    constexpr TextualFilter() noexcept = default;
    bool operator==(const TextualFilter &_r) const noexcept;
    bool operator!=(const TextualFilter &_r) const noexcept;
    static Where WhereFromInt(int _v) noexcept;
    static TextualFilter NoFilter() noexcept;
    bool IsValidItem(const VFSListingItem &_item, QuickSearchHiglight &_found_range) const;
    bool IsValidItem(const VFSListingItem &_item) const;
    void OnPanelDataLoad();
    bool IsFiltering() const noexcept;
} __attribute__((packed));

struct HardFilter {
    TextualFilter text = TextualFilter::NoFilter();
    bool show_hidden = true;
    bool IsValidItem(const VFSListingItem &_item, QuickSearchHiglight &_found_range) const;
    bool IsFiltering() const noexcept;
    bool operator==(const HardFilter &_r) const noexcept = default;
    bool operator!=(const HardFilter &_r) const noexcept = default;
};

std::optional<QuickSearchHiglight> FuzzySearch(NSString *_filename, NSString *_text) noexcept;

} // namespace nc::panel::data
