// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

struct FollowSymlink final : PanelAction {
    [[nodiscard]] bool Predicate(PanelController *_target) const override;
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

} // namespace nc::panel::actions
