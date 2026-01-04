// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class MainWindowFilePanelState;

namespace nc::panel::actions {

class FocusOverlappedTerminal final : public StateAction
{
public:
    [[nodiscard]] bool Predicate(MainWindowFilePanelState *_target) const override;
    [[nodiscard]] bool ValidateMenuItem(MainWindowFilePanelState *_target, NSMenuItem *_item) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

} // namespace nc::panel::actions
