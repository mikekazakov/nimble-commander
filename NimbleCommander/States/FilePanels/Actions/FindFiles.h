#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

struct FindFiles : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

};
