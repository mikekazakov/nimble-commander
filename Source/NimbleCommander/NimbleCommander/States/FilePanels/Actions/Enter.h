// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"
#include "GoToFolder.h"
#include "ExecuteInTerminal.h"

namespace nc::panel::actions {

struct Enter final : PanelAction {
    Enter(const PanelAction &_open_files_action);
    bool Predicate(PanelController *_target) const override;
    bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const PanelAction &m_OpenFilesAction;
    GoIntoFolder m_GoIntoFolder;
    ExecuteInTerminal m_ExecuteInTerminal;
};

} // namespace nc::panel::actions
