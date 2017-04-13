#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct CalculateSizes : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

struct CalculateAllSizes : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

}
