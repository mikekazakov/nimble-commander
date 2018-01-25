// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Favorites.h"

class GenericConfig;

namespace nc::panel {
    
// STA API design at the moment, call it only from main thread!
class FavoriteLocationsStorageImpl : public FavoriteLocationsStorage
{
public:

    FavoriteLocationsStorageImpl( GenericConfig &_config, const char *_path );
    void StoreData( GenericConfig &_config, const char *_path );
    
    void AddFavoriteLocation( Favorite _favorite ) override;
    
    optional<Favorite> ComposeFavoriteLocation(VFSHost &_host,
                                               const string &_directory,
                                               const string &_title = "" ) const override;
    
    void SetFavorites( const vector<Favorite> &_new_favorites ) override;
    vector<Favorite> Favorites( /*limit output later?*/ ) const override;
    
    // Recent locations management
    void ReportLocationVisit( VFSHost &_host, const string &_directory ) override;
    vector< shared_ptr<const Location> > FrecentlyUsed( int _amount ) const override;
    void ClearVisitedLocations() override;
    
    ObservationTicket ObserveFavoritesChanges( function<void()> _callback ) override;
    
private:
    enum ObservationEvents : uint64_t {
        FavoritesChanged = 1
    };
    
    struct Visit
    {
        shared_ptr<const Location>  location;
        int                         visits_count = 0;
        time_t                      last_visit = 0;
    };
    
    shared_ptr<const Location> FindInVisitsOrEncode(size_t _footprint,
                                                    VFSHost &_host,
                                                    const string &_directory);
    
    void LoadData( GenericConfig &_config, const char *_path );
    
    static optional<rapidjson::StandaloneValue> VisitToJSON(const Visit &_visit);
    static optional<Visit> JSONToVisit( const rapidjson::StandaloneValue& _json );
    
    static optional<rapidjson::StandaloneValue> FavoriteToJSON(const Favorite &_favorite);
    static optional<Favorite> JSONToFavorite( const rapidjson::StandaloneValue& _json );
    
    
    unordered_map<size_t, Visit>    m_Visits;
    vector<Favorite>                m_Favorites;
};
    
}
