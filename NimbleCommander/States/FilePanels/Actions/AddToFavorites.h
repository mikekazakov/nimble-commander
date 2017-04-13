#pragma once

#include "DefaultAction.h"

namespace panel::actions {

// has en external dependency: AppDelegate.me.favoriteLocationsStorage
struct AddToFavorites : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

};
