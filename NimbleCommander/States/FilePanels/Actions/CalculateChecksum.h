#pragma once

#include "DefaultAction.h"

namespace panel::actions {

struct CalculateChecksum : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

};
