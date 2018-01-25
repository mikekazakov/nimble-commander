// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/Observable.h>
#include <VFS/VFS.h>
#include "PanelDataPersistency.h"

namespace nc::panel {

// STA API design at the moment, call it only from main thread!
class FavoriteLocationsStorage : protected ObservableBase
{
public:
    struct Location
    {
        nc::panel::PersistentLocation   hosts_stack;
        string                          verbose_path;
    };
    
    struct Favorite
    {
        shared_ptr<const Location> location;
        size_t footprint = 0;
        string title;
    };

    virtual ~FavoriteLocationsStorage() = default;

    // Favorite locations management
    virtual optional<Favorite> ComposeFavoriteLocation(VFSHost &_host,
                                                       const string &_directory,
                                                       const string &_title = "" ) const = 0;
    virtual void AddFavoriteLocation( Favorite _favorite ) = 0;
    virtual void SetFavorites( const vector<Favorite> &_new_favorites ) = 0;
    virtual vector<Favorite> Favorites( /*limit output later?*/ ) const = 0;
    
    // Recent locations management
    virtual void ReportLocationVisit( VFSHost &_host, const string &_directory ) = 0;
    virtual vector< shared_ptr<const Location> > FrecentlyUsed( int _amount ) const = 0;
    virtual void ClearVisitedLocations() = 0;

    // Changes observation
    using ObservationTicket = ObservableBase::ObservationTicket;
    virtual ObservationTicket ObserveFavoritesChanges( function<void()> _callback ) = 0;
};
    
// https://wiki.mozilla.org/User:Jesse/NewFrecency
// https://developer.mozilla.org/en-US/docs/Mozilla/Tech/Places/Frecency_algorithm

}
