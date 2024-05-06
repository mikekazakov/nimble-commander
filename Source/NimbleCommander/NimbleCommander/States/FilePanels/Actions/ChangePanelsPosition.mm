// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChangePanelsPosition.h"
#include "../MainWindowFilePanelState.h"
#include "../MainWindowFilePanelState+OverlappedTerminalSupport.h"

namespace nc::panel::actions {

bool MovePanelsUp::Predicate(MainWindowFilePanelState *_target) const
{
    return [_target canIncreaseBootomTerminalGap];
}

void MovePanelsUp::Perform(MainWindowFilePanelState *_target, [[maybe_unused]] id _sender) const
{
    [_target increaseBottomTerminalGap];
}

bool MovePanelsDown::Predicate(MainWindowFilePanelState *_target) const
{
    return [_target canDecreaseBottomTerminalGap];
}

void MovePanelsDown::Perform(MainWindowFilePanelState *_target, [[maybe_unused]] id _sender) const
{
    [_target decreaseBottomTerminalGap];
}

bool ShowHidePanels::Predicate([[maybe_unused]] MainWindowFilePanelState *_target) const
{
    return true; // TODO: need a way to query overlapped terminal state. there actually might be no
                 // terminal at all.
}

bool ShowHidePanels::ValidateMenuItem(MainWindowFilePanelState *_target, NSMenuItem *_item) const
{
    if( _target.isPanelsSplitViewHidden ) {
        _item.title = NSLocalizedString(@"Show Panels", "Menu item for showing panels");
    }
    else {
        _item.title = NSLocalizedString(@"Hide Panels", "Menu item for hiding panels");
    }

    return Predicate(_target);
}

void ShowHidePanels::Perform(MainWindowFilePanelState *_target, [[maybe_unused]] id _sender) const
{
    if( _target.isPanelsSplitViewHidden )
        [_target showPanelsSplitView];
    else
        [_target hidePanelsSplitView];
}

} // namespace nc::panel::actions
