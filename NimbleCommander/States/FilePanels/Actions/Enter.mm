// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Enter.h"
#include "GoToFolder.h"
#include "ExecuteInTerminal.h"
#include "OpenFile.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

Enter::Enter(bool _support_archives,
             const PanelAction &_open_files_action):
    m_SupportArchives(_support_archives),
    m_OpenFilesAction(_open_files_action)
{
}
    
bool Enter::Predicate( PanelController *_target ) const
{
    return _target.view.item;
}

bool Enter::ValidateMenuItem( PanelController *_target, [[maybe_unused]] NSMenuItem *_item ) const
{
    // TODO: add a proper title like:
    // Enter "Directory"
    // Execute "uptime"
    // Open "abra.h" ???
    return Predicate(_target);
}

void Enter::Perform( PanelController *_target, id _sender ) const
{
    if( actions::GoIntoFolder{m_SupportArchives, false}.Predicate(_target) ) {
        actions::GoIntoFolder{m_SupportArchives, false}.Perform(_target, _sender);
        return;
    }
    
    if( actions::ExecuteInTerminal{}.Predicate(_target) ) {
        actions::ExecuteInTerminal{}.Perform(_target, _sender);
        return;
    }
    
    m_OpenFilesAction.Perform(_target, _sender);
}

}
