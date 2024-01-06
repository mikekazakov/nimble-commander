// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Favorites.h"

namespace nc::panel {

class FavoriteComposing
{
public:
    FavoriteComposing(const FavoriteLocationsStorage& _storage);
    using Favorite = FavoriteLocationsStorage::Favorite;

#ifdef __OBJC__
    std::optional<Favorite> FromURL( NSURL *_url );
#endif
    std::optional<Favorite> FromListingItem( const VFSListingItem &_i );

    std::vector<Favorite> FinderFavorites();
    std::vector<Favorite> DefaultFavorites();
private:
    const FavoriteLocationsStorage& m_Storage;
    
};

}
