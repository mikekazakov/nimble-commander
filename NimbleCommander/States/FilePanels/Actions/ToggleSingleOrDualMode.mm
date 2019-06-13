// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ToggleSingleOrDualMode.h"
#include "../MainWindowFilePanelState.h"
#include "../Views/FilePanelMainSplitView.h"

namespace nc::panel::actions {

static const auto g_ToggleDualPaneModeTitle =
NSLocalizedString(@"Toggle Dual-Pane Mode", "Menu item title for switching to dual-pane mode");
    
static const auto g_ToggleSinglePaneModeTitle =
NSLocalizedString(@"Toggle Single-Pane Mode", "Menu item title for switching to single-pane mode");

bool ToggleSingleOrDualMode::ValidateMenuItem(MainWindowFilePanelState *_target,
                                              NSMenuItem *_item ) const
{
    _item.title = _target.splitView.anyCollapsed ?
                    g_ToggleDualPaneModeTitle :
                    g_ToggleSinglePaneModeTitle;
    return Predicate(_target);
}

void ToggleSingleOrDualMode::Perform( MainWindowFilePanelState *_target, id ) const
{
    const auto split_view = _target.splitView;
    if( split_view.anyCollapsed ) {
        if( split_view.isLeftCollapsed )
            [split_view expandLeftView];
        else if( split_view.isRightCollapsed )
            [split_view expandRightView];
    }
    else if( const auto apc = _target.activePanelController) {
        if( apc == _target.leftPanelController )
            [split_view collapseRightView];
        else if( apc == _target.rightPanelController )
            [split_view collapseLeftView];
    }
}

}
