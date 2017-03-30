#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "../Favorites.h"
#include "../FavoriteComposing.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "AddToFavorites.h"

namespace panel::actions {

bool AddToFavorites::Predicate( PanelController *_target )
{
    return _target.isUniform || _target.view.item;
}

bool AddToFavorites::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void AddToFavorites::Perform( PanelController *_target, id _sender )
{
    auto &favorites = AppDelegate.me.favoriteLocationsStorage;
    if( auto item = _target.view.item ) {
        if( auto favorite = FavoriteComposing::FromListingItem(item) )
            favorites.AddFavoriteLocation( move(*favorite) );
    }
    else if( _target.isUniform )
        favorites.AddFavoriteLocation( *_target.vfs, _target.currentDirectoryPath );
}

};
