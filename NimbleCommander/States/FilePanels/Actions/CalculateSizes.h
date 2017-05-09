#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

struct CalculateSizes : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct CalculateAllSizes : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

}
