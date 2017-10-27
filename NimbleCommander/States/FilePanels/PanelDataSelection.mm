// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ExtensionLowercaseComparison.h>
#include <NimbleCommander/Core/FileMask.h>
#include "PanelDataSelection.h"
#include "PanelData.h"
#include "PanelDataItemVolatileData.h"
#include <VFS/VFS.h>

namespace nc::panel::data {

SelectionBuilder::SelectionBuilder(const Model &_pd, bool _ignore_dirs_on_mask):
    m_Data(_pd),
    m_IgnoreDirectoriesOnMaskSelection(_ignore_dirs_on_mask)
{
}

vector<bool> SelectionBuilder::SelectionByExtension(const string &_extension,
                                                    bool _result_selection ) const
{
    auto &comparison = ExtensionLowercaseComparison::Instance();
    const auto extension = comparison.ExtensionToLowercase( _extension );
    const auto empty = extension.empty();
    const auto count = m_Data.SortedEntriesCount();

    vector<bool> selection(count);
    const auto &listing = m_Data.Listing();
    for( int i = 0, e = count; i != e; ++i  ) {
        const auto raw_index = m_Data.RawIndexForSortIndex(i);
        selection[i] = m_Data.VolatileDataAtRawPosition(raw_index).is_selected();
    
        if( m_IgnoreDirectoriesOnMaskSelection && listing.IsDir(raw_index) )
            continue;
        
        bool legit = false;
        if( listing.HasExtension(raw_index) ) {
            if(comparison.Equal(listing.Extension(raw_index), extension))
                legit = true;
        }
        else if( empty )
            legit = true;
        
        if( legit )
            selection[i] = _result_selection;
    }
    return selection;
}

vector<bool> SelectionBuilder::SelectionByMask(const string &_mask,
                                                 bool _result_selection ) const
{
    FileMask mask(_mask);
    const auto count = m_Data.SortedEntriesCount();
    vector<bool> selection(count);
    const auto &listing = m_Data.Listing();
    for( int i = 0, e = count; i != e; ++i  ) {
        const auto raw_index = m_Data.RawIndexForSortIndex(i);
        selection[i] = m_Data.VolatileDataAtRawPosition(raw_index).is_selected();
    
        if( m_IgnoreDirectoriesOnMaskSelection && listing.IsDir(raw_index) )
            continue;

        if( mask.MatchName(listing.DisplayFilename(raw_index)) )
            selection[i] = _result_selection;
    }
    
    return selection;
}

vector<bool> SelectionBuilder::InvertSelection() const
{
    const auto count = m_Data.SortedEntriesCount();
    vector<bool> selection(count);
    for( int i = 0; i < count; ++i )
        selection[i] = !m_Data.VolatileDataAtSortPosition(i).is_selected();
    return selection;
}

}
