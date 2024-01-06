// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// external dependencies:
// config: filePanel.spotlight.format;
// config: filePanel.spotlight.maxCount;

struct SpotlightSearch final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

};
