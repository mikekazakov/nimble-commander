// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::config {
class Config;
}

namespace nc::panel::actions {

struct ChangeAttributes final : PanelAction {
    ChangeAttributes(nc::config::Config &_config);
    [[nodiscard]] bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::config::Config &m_Config;
};

}; // namespace nc::panel::actions
