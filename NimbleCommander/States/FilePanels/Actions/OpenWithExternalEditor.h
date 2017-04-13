#pragma once

#include "DefaultAction.h"

namespace panel::actions {

// has en external dependency: AppDelegate.me.externalEditorsStorage
struct OpenWithExternalEditor : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

};
