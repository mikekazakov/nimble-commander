// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CalculateSizes.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include "../PanelView.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

bool CalculateSizes::Predicate( PanelController *_target ) const
{
    auto i = _target.view.item;
    return i && (i.IsDir() || _target.data.Stats().selected_dirs_amount > 0 );
}

void CalculateSizes::Perform( PanelController *_target, id _sender ) const
{
    auto selected = _target.selectedEntriesOrFocusedEntryWithDotDot;
    selected.erase(remove_if(begin(selected),
                             end(selected), [](auto &v){ return !v.IsDir(); }),
                   end(selected)
                   );
    [_target calculateSizesOfItems:selected];
}

void CalculateAllSizes::Perform( PanelController *_target, id _sender ) const
{
    std::vector<VFSListingItem> items;
    auto &data = _target.data;
    for( auto ind: data.SortedDirectoryEntries() )
        if( auto e = data.EntryAtRawPosition(ind) )
            if( e.IsDir()  )
                items.emplace_back( std::move(e) );

    [_target calculateSizesOfItems:items];
}

}
