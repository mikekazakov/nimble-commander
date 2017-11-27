// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {
    
struct RefreshPanel final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};
    
};
