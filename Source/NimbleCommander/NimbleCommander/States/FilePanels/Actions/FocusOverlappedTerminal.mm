// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FocusOverlappedTerminal.h"
#include "../MainWindowFilePanelState.h"
#include "../MainWindowFilePanelState+OverlappedTerminalSupport.h"

namespace nc::panel::actions {

bool FocusOverlappedTerminal::Predicate([[maybe_unused]] MainWindowFilePanelState *_target) const
{
    return _target.overlappedTerminalVisible && !_target.isPanelsSplitViewHidden;
}

bool FocusOverlappedTerminal::ValidateMenuItem(MainWindowFilePanelState *_target, NSMenuItem *_item) const
{
    if( _target.isPanelActive ) {
        _item.title = NSLocalizedString(@"Focus Overlapped Terminal", "Menu item for focusing an overlapped terminal");
    }
    else {
        _item.title = NSLocalizedString(@"Focus File Panels", "Menu item for focusing file panels");
    }

    return Predicate(_target);
}

void FocusOverlappedTerminal::Perform(MainWindowFilePanelState *_target, [[maybe_unused]] id _sender) const
{
    [_target handleCtrlAltTab];
}

} // namespace nc::panel::actions
