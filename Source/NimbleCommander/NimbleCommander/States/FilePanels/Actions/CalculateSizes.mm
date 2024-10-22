// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CalculateSizes.h"
#include "../PanelController.h"
#include <Panel/PanelData.h>
#include "../PanelView.h"
#include <VFS/VFS.h>

#include <algorithm>

namespace nc::panel::actions {

bool CalculateSizes::Predicate(PanelController *_target) const
{
    auto i = _target.view.item;
    return i && (i.IsDir() || _target.data.Stats().selected_dirs_amount > 0);
}

void CalculateSizes::Perform(PanelController *_target, id /*_sender*/) const
{
    auto selected = _target.selectedEntriesOrFocusedEntryWithDotDot;
    std::erase_if(selected, [](auto &v) { return !v.IsDir(); });
    [_target calculateSizesOfItems:selected];
}

void CalculateAllSizes::Perform(PanelController *_target, id /*_sender*/) const
{
    std::vector<VFSListingItem> items;
    auto &data = _target.data;
    for( auto ind : data.SortedDirectoryEntries() )
        if( auto e = data.EntryAtRawPosition(ind) )
            if( e.IsDir() )
                items.emplace_back(std::move(e));

    [_target calculateSizesOfItems:items];
}

} // namespace nc::panel::actions
