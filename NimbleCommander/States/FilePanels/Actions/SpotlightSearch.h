#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// external dependencies:
// config: filePanel.spotlight.format;
// config: filePanel.spotlight.maxCount;

struct SpotlightSearch : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

};
