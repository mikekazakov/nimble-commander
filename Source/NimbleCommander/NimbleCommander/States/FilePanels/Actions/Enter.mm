// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Enter.h"
#include "GoToFolder.h"
#include "ExecuteInTerminal.h"
#include "OpenFile.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

Enter::Enter(const PanelAction &_open_files_action)
    : m_OpenFilesAction(_open_files_action), m_GoIntoFolder(true, false)
{
}

bool Enter::Predicate(PanelController *_target) const
{
    return _target.view.item;
}

bool Enter::ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const
{
    if( m_GoIntoFolder.Predicate(_target) ) {
        return m_GoIntoFolder.ValidateMenuItem(_target, _item);
    }

    if( m_ExecuteInTerminal.Predicate(_target) ) {
        return m_ExecuteInTerminal.ValidateMenuItem(_target, _item);
    }

    return m_OpenFilesAction.ValidateMenuItem(_target, _item);
}

void Enter::Perform(PanelController *_target, id _sender) const
{
    if( m_GoIntoFolder.Predicate(_target) ) {
        m_GoIntoFolder.Perform(_target, _sender);
        return;
    }

    if( m_ExecuteInTerminal.Predicate(_target) ) {
        m_ExecuteInTerminal.Perform(_target, _sender);
        return;
    }

    m_OpenFilesAction.Perform(_target, _sender);
}

} // namespace nc::panel::actions
