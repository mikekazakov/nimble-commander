// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

struct CalculateSizes final : PanelAction {
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct CalculateAllSizes final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

} // namespace nc::panel::actions
