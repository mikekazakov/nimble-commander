// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"
#include "GoToFolder.h"
#include "ExecuteInTerminal.h"

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::panel::actions {

struct Enter final : PanelAction
{
    Enter(nc::bootstrap::ActivationManager &_am, const PanelAction &_open_files_action);
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    nc::bootstrap::ActivationManager &m_ActivationManager;
    const PanelAction &m_OpenFilesAction;
    GoIntoFolder m_GoIntoFolder;
    ExecuteInTerminal m_ExecuteInTerminal;
};

}
