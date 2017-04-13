#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct BatchRename : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};


}
