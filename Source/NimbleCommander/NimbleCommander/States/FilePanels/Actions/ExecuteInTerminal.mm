// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExecuteInTerminal.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include <VFS/VFS.h>
#include <Base/debug.h>

namespace nc::panel::actions {

bool ExecuteInTerminal::Predicate(PanelController *_target) const
{
    if( base::AmISandboxed() )
        return false;

    const auto item = _target.view.item;
    if( !item || !item.Host()->IsNativeFS() )
        return false;

    return IsEligbleToTryToExecuteInConsole(item);
}

bool ExecuteInTerminal::ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const
{
    if( auto vfs_item = _target.view.item ) {
        _item.title = [NSString stringWithFormat:NSLocalizedString(@"Execute \u201c%@\u201d", "Execute a binary"),
                                                 vfs_item.DisplayNameNS()];
    }
    return Predicate(_target);
}

void ExecuteInTerminal::Perform(PanelController *_target, id /*_sender*/) const
{
    if( !Predicate(_target) )
        return;

    const auto item = _target.view.item;
    [_target.state requestTerminalExecution:item.Filename() at:item.Directory()];
}

} // namespace nc::panel::actions
