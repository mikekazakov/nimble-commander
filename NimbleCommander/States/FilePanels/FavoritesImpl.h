// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Favorites.h"
#include <Config/Config.h>

namespace nc::panel {
    
// STA API design at the moment, call it only from main thread!
class FavoriteLocationsStorageImpl : public FavoriteLocationsStorage
{
public:

    FavoriteLocationsStorageImpl( config::Config &_config, const char *_path );
    void StoreData( config::Config &_config, const char *_path );
    
    void AddFavoriteLocation( Favorite _favorite ) override;
    
    std::optional<Favorite> ComposeFavoriteLocation(VFSHost &_host,
                                                    const std::string &_directory,
                                                    const std::string &_title = "" ) const override;
    
    void SetFavorites( const std::vector<Favorite> &_new_favorites ) override;
    std::vector<Favorite> Favorites( /*limit output later?*/ ) const override;
    
    // Recent locations management
    void ReportLocationVisit( VFSHost &_host, const std::string &_directory ) override;
    std::vector< std::shared_ptr<const Location> > FrecentlyUsed( int _amount ) const override;
    void ClearVisitedLocations() override;
    
    ObservationTicket ObserveFavoritesChanges( std::function<void()> _callback ) override;
    
private:
    enum ObservationEvents : uint64_t {
        FavoritesChanged = 1
    };
    
    struct Visit
    {
        std::shared_ptr<const Location>  location;
        int                         visits_count = 0;
        time_t                      last_visit = 0;
    };
    
    std::shared_ptr<const Location> FindInVisitsOrEncode(size_t _footprint,
                                                    VFSHost &_host,
                                                    const std::string &_directory);
    
    void LoadData( config::Config &_config, const char *_path );
    
    static nc::config::Value VisitToJSON(const Visit &_visit);
    static std::optional<Visit> JSONToVisit( const nc::config::Value& _json );
    
    static nc::config::Value FavoriteToJSON(const Favorite &_favorite);
    static std::optional<Favorite> JSONToFavorite( const nc::config::Value& _json );
    
    
    std::unordered_map<size_t, Visit> m_Visits;
    std::vector<Favorite>             m_Favorites;
};
    
}
