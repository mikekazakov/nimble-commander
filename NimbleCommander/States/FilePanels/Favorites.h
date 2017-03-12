#pragma once

#include "PanelDataPersistency.h"

class VFSHost;
class GenericConfig;

//class VisitedLocation
//{
//    
//    // shared_ptr<data> :
//        // vector<PanelDataPersistency::Host> hosts_stack
//        // string directory;
//        // string verbose_path;
//   
//  
//    size_t  footprint;
//    int     visits_count;
//    time_t  last_vist;
//};

class FavoriteLocationsStorage
{

public:
    struct Location
    {
//        rapidjson::StandaloneValue hosts_stack; // might change this to something more memory-friendly
        PanelDataPersisency::Location   hosts_stack;
        string                          verbose_path;
    };
    
    struct Favorite
    {
        shared_ptr<const Location> location;
        size_t footprint = 0; // do not store hashes, they aren't obliged to be the same after restart
        string filename;
        string title;
    };


    FavoriteLocationsStorage( GenericConfig &_config, const char *_path );
    
    void LoadData( GenericConfig &_config, const char *_path );
    void StoreData( GenericConfig &_config, const char *_path );
    
    
    void AddFavoriteLocation(VFSHost &_host,
                             const string &_directory,
                             const string &_filename = "",
                             const string &_title = "");
    
    
    void ReportLocationVisit( VFSHost &_host, const string &_directory );


    vector< shared_ptr<const Location> > FrecentlyUsed( int _amount ) const;
    vector<Favorite> Favorites( /*limit output later*/ ) const;

// add favorites with vfs and directory path
// report location usage - vfs and directory

private:
    struct Visit;
    static optional<Visit> JSONToVisit( const rapidjson::StandaloneValue& _json );
    static optional<rapidjson::StandaloneValue> VisitToJSON(const Visit &_visit);
    static optional<rapidjson::StandaloneValue> FavoriteToJSON(const Favorite &_favorite);
    

    unordered_map<size_t, Visit>    m_Visits;
    vector<Favorite>                m_Favorites;
    

};
// https://wiki.mozilla.org/User:Jesse/NewFrecency
// https://developer.mozilla.org/en-US/docs/Mozilla/Tech/Places/Frecency_algorithm
