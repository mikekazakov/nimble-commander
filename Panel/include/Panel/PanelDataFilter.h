// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::panel::data {

struct TextualFilter
{
    enum Where : int8_t // persistancy-bound values, don't change it
    {
        Anywhere            = 0,
        Beginning           = 1,
        Ending              = 2, // handling extensions somehow
        BeginningOrEnding   = 3
    };
    
    using FoundRange = std::pair<int16_t, int16_t>; // begin-end indeces range in DispayName string, {0,0} mean empty
    
    NSString *text;
    Where     type;
    bool ignore_dot_dot:1; // will not apply filter on dot-dot entries
    bool clear_on_new_listing:1; // if true then PanelData will automatically set text to nil on Load method call
    bool hightlight_results:1; // option for PanelData to mark QS hightlight
    
    TextualFilter() noexcept;
    bool operator==(const TextualFilter& _r) const noexcept;
    bool operator!=(const TextualFilter& _r) const noexcept;
    static Where WhereFromInt(int _v) noexcept;
    static TextualFilter NoFilter() noexcept;
    bool IsValidItem(const VFSListingItem& _item, FoundRange &_found_range) const;
    bool IsValidItem(const VFSListingItem& _item) const;
    void OnPanelDataLoad();
    bool IsFiltering() const noexcept;
} __attribute__((packed));

struct HardFilter
{
    TextualFilter text = TextualFilter::NoFilter();
    bool show_hidden = true;
    bool IsValidItem(const VFSListingItem& _item, TextualFilter::FoundRange &_found_range) const;
    bool IsFiltering() const noexcept;
    bool operator==(const HardFilter& _r) const noexcept;
    bool operator!=(const HardFilter& _r) const noexcept;
};

}
