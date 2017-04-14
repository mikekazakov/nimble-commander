//#include <Utility/ExtensionLowercaseComparison.h>
#include "Select.h"
#include "../PanelDataSelection.h"
#include "../PanelController.h"

namespace panel::actions {

void SelectAll::Perform( PanelController *_target, id _sender ) const
{
    [_target setEntriesSelection: vector<bool>(_target.data.SortedEntriesCount(), true) ];
}

void DeselectAll::Perform( PanelController *_target, id _sender ) const
{
    [_target setEntriesSelection: vector<bool>(_target.data.SortedEntriesCount(), false) ];
}

void InvertSelection::Perform( PanelController *_target, id _sender ) const
{
//    const auto &data = _target.data;
//    const auto count = data.SortedEntriesCount();
//    vector<bool> target(count);
//    for( int i = 0; i < count; ++i )
//        target[i] = !data.VolatileDataAtSortPosition(i).is_selected();
    auto selector = PanelDataSelection(_target.data);
    [_target setEntriesSelection:selector.InvertSelection()];
}

SelectAllByExtension::SelectAllByExtension( bool _result_selection ):
    m_ResultSelection(_result_selection)
{
}

bool SelectAllByExtension::Predicate( PanelController *_target ) const
{
    return _target.view.item;
}

void SelectAllByExtension::Perform( PanelController *_target, id _sender ) const
{
    auto item = _target.view.item;
    if( !item )
        return;
    
    const string extension = item.HasExtension() ? item.Extension() : "";
    auto selector = PanelDataSelection(_target.data,
                                       _target.ignoreDirectoriesOnSelectionByMask);
    auto selection = selector.SelectionByExtension(extension, m_ResultSelection);
    [_target setEntriesSelection:selection];
}

}


//- (void)DoQuickSelectByExtension:(bool)_select
//{
//    if( auto item = self.view.item )
//        if( m_Data.CustomFlagsSelectAllSortedByExtension(item.HasExtension() ? item.Extension() : "", _select, self.ignoreDirectoriesOnSelectionByMask) )
//           [m_View volatileDataChanged];
//}
//
//unsigned PanelData::CustomFlagsSelectAllSortedByExtension(const string &_extension, bool _select, bool _ignore_dirs)
//{
//    const auto extension = ExtensionLowercaseComparison::Instance().ExtensionToLowercase(_extension);
//    const bool empty = extension.empty();
//    unsigned counter = 0;
//    for(auto i: m_EntriesByCustomSort) {
//        if( _ignore_dirs && m_Listing->IsDir(i) )
//            continue;
//        
//        if( m_Listing->IsDotDot(i) )
//            continue;
//
//        bool legit = false;
//        if( m_Listing->HasExtension(i) ) {
//            if(ExtensionLowercaseComparison::Instance().Equal(m_Listing->Extension(i), extension))
//                legit = true;
//        }
//        else if( empty )
//            legit = true;
//
//        if( legit ) {
//            CustomFlagsSelectRaw(i, _select);
//            counter++;
//        }
//    }
//    
//    return counter;
//}
