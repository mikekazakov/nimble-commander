// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// this actions relies on the global state via config: tabs can shown either in every window or
// in none. The action participates in common actions infrastructure for a sake of uniformity.
struct ShowTabs final : StateAction
{
    bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const override;
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
};

}
