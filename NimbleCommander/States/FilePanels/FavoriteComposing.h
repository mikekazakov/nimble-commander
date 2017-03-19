#pragma once

#include "Favorites.h"

class FavoriteComposing
{
public:
    using Favorite = FavoriteLocationsStorage::Favorite;

#ifdef __OBJC__
    static optional<Favorite> FromURL( NSURL *_url );
#endif
    static optional<Favorite> FromListingItem( const VFSListingItem &_i );

    static vector<Favorite> FinderFavorites();
    static vector<Favorite> DefaultFavorites();

};
