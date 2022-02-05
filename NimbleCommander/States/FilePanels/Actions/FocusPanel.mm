// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FocusPanel.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelView.h"
#include "../Views/FilePanelMainSplitView.h"

namespace nc::panel::actions {

void FocusLeftPanel::Perform(MainWindowFilePanelState *_target, [[maybe_unused]] id _sender) const
{
    auto sv = _target.splitView;
    if( sv.isLeftCollapsed )
        [sv expandLeftView];

    if( auto cur_pc = _target.activePanelController ) {
        if( ![_target isLeftController:cur_pc] )
            [_target.window makeFirstResponder:sv.leftTabbedHolder.current];
    }
    else {
        [_target.window makeFirstResponder:sv.leftTabbedHolder.current];
    }
}

void FocusRightPanel::Perform(MainWindowFilePanelState *_target, [[maybe_unused]] id _sender) const
{
    auto sv = _target.splitView;
    if( sv.isRightCollapsed )
        [sv expandRightView];
    if( auto cur_pc = _target.activePanelController ) {
        if( ![_target isRightController:cur_pc] )
            [_target.window makeFirstResponder:sv.rightTabbedHolder.current];
    }
    else {
        [_target.window makeFirstResponder:sv.rightTabbedHolder.current];
    }
}

} // namespace nc::panel::actions
