// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "DefaultAction.h"

namespace nc::panel::actions {
    
struct ShowTerminal final : StateAction
{
    bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const override;
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
};

}
