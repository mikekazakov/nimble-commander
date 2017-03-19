#pragma once

#include <Habanero/Observable.h>
#include "PanelDataPersistency.h"

class VFSHost;
class GenericConfig;

// STA API design at the moment, call it only from main thread!
class FavoriteLocationsStorage : ObservableBase
{
public:
    struct Location
    {
        PanelDataPersisency::Location   hosts_stack;
        string                          verbose_path;
    };
    
    struct Favorite
    {
        shared_ptr<const Location> location;
        size_t footprint = 0;
        string title;
    };

    FavoriteLocationsStorage( GenericConfig &_config, const char *_path );
    

    void StoreData( GenericConfig &_config, const char *_path );
    
    
    void AddFavoriteLocation(VFSHost &_host,
                             const string &_directory,
                             const string &_title = "");
    void AddFavoriteLocation( Favorite _favorite );
    static optional<Favorite> ComposeFavoriteLocation(VFSHost &_host,
                                                      const string &_directory,
                                                      const string &_title = "" );
    
    
    void SetFavorites( const vector<Favorite> &_new_favorites );
    
    
    void ReportLocationVisit( VFSHost &_host, const string &_directory );


    vector< shared_ptr<const Location> > FrecentlyUsed( int _amount ) const;
    vector<Favorite> Favorites( /*limit output later?*/ ) const;

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
// https://wiki.mozilla.org/User:Jesse/NewFrecency
// https://developer.mozilla.org/en-US/docs/Mozilla/Tech/Places/Frecency_algorithm
