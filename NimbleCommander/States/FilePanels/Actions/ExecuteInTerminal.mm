// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExecuteInTerminal.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <VFS/VFS.h>

namespace nc::panel::actions {

bool ExecuteInTerminal::Predicate( PanelController *_target ) const
{
    if( !bootstrap::ActivationManager::Instance().HasTerminal() )
        return false;

    const auto item = _target.view.item;
    if( !item || !item.Host()->IsNativeFS() )
        return false;
    
    return IsEligbleToTryToExecuteInConsole(item);
}

void ExecuteInTerminal::Perform( PanelController *_target, id ) const
{
    if( !Predicate(_target) )
        return;

    const auto item = _target.view.item;
    [_target.state requestTerminalExecution:item.Filename()
                                         at:item.Directory()];
}

}
