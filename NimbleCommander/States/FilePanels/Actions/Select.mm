// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Select.h"
#include <Utility/FileMask.h>
#include "../Views/SelectionWithMaskPopupViewController.h"
#include "../PanelDataSelection.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include "../PanelView.h"
#include <VFS/VFS.h>
#include <Utility/StringExtras.h>

namespace nc::panel::actions {

void SelectAll::Perform( PanelController *_target, id _sender ) const
{
    [_target setEntriesSelection: std::vector<bool>(_target.data.SortedEntriesCount(), true) ];
}

void DeselectAll::Perform( PanelController *_target, id _sender ) const
{
    [_target setEntriesSelection: std::vector<bool>(_target.data.SortedEntriesCount(), false) ];
}

void InvertSelection::Perform( PanelController *_target, id _sender ) const
{
    auto selector = data::SelectionBuilder(_target.data);
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
    
    const std::string extension = item.HasExtension() ? item.Extension() : "";
    auto selector = data::SelectionBuilder(_target.data,
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
    const auto view = [[SelectionWithMaskPopupViewController alloc] initForWindow:_target.window
                                                                       doesSelect:m_ResultSelection];
    __weak PanelController *wp = _target;
    view.handler = [wp, this](NSString *_mask) {
        if( PanelController *panel = wp ) {
            std::string mask = _mask.fileSystemRepresentationSafe;
            if( !utility::FileMask::IsWildCard(mask) )
                mask = utility::FileMask::ToExtensionWildCard(mask);
            
            auto selector = data::SelectionBuilder(panel.data,
                                                   panel.ignoreDirectoriesOnSelectionByMask);
            auto selection = selector.SelectionByMask(mask, m_ResultSelection);
            [panel setEntriesSelection:selection];
        }
    };
    
    [_target.view showPopoverUnderPathBarWithView:view andDelegate:view];
}

}
