#include "Select.h"
#include <NimbleCommander/Core/FileMask.h>
#include "../Views/SelectionWithMaskPopupViewController.h"
#include "../PanelDataSelection.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include "../PanelView.h"

namespace nc::panel::actions {

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

SelectAllByMask::SelectAllByMask( bool _result_selection ):
    m_ResultSelection(_result_selection)
{
}

void SelectAllByMask::Perform( PanelController *_target, id _sender ) const
{
    SelectionWithMaskPopupViewController *view = [[SelectionWithMaskPopupViewController alloc]
        initForWindow:_target.window doesSelect:m_ResultSelection];
    view.handler = [=](NSString *_mask) {
        string mask = _mask.fileSystemRepresentationSafe;
        if( !FileMask::IsWildCard(mask) )
            mask = FileMask::ToExtensionWildCard(mask);
        
        auto selector = PanelDataSelection(_target.data,
                                           _target.ignoreDirectoriesOnSelectionByMask);
        auto selection = selector.SelectionByMask(mask, m_ResultSelection);
        [_target setEntriesSelection:selection];
    };
    
    [_target.view showPopoverUnderPathBarWithView:view andDelegate:view];
}

}
