// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "../Favorites.h"
#include "../FavoriteComposing.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "AddToFavorites.h"
#include "../PanelDataPersistency.h"

namespace nc::panel::actions {

bool AddToFavorites::Predicate( PanelController *_target ) const
{
    return _target.isUniform || _target.view.item;
}

void AddToFavorites::Perform( PanelController *_target, [[maybe_unused]] id _sender ) const
{
    auto &favorites = NCAppDelegate.me.favoriteLocationsStorage;
    if( auto item = _target.view.item ) {
        if( auto favorite = FavoriteComposing{*favorites}.FromListingItem(item) )
            favorites->AddFavoriteLocation( std::move(*favorite) );
    }
    else if( _target.isUniform ) {
        if( auto favorite = favorites->ComposeFavoriteLocation(*_target.vfs,
                                                              _target.currentDirectoryPath) ) {
            favorites->AddFavoriteLocation(std::move(*favorite));
        }
    }
}

};
