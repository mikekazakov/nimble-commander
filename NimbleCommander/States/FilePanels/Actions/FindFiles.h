#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct FindFiles : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

};
