#pragma once

@class PanelController;

namespace panels::actions {

// has en external dependency: AppDelegate.me.favoriteLocationsStorage
struct AddToFavorites
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

};
