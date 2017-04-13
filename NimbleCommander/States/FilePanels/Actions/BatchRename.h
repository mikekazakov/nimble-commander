#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct BatchRename : PanelAction
{
    bool Predicate( PanelController *_target );
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};


}
