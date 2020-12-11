// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::bootstrap {
    class ActivationManager;
}

namespace nc::panel::actions {

struct ExecuteInTerminal final : PanelAction
{
    ExecuteInTerminal(nc::bootstrap::ActivationManager &_am);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

}
