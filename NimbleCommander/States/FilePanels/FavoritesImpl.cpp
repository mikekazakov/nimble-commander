// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FavoritesImpl.h"
#include <CoreServices/CoreServices.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <Config/RapidJSON.h>
#include "FavoriteComposing.h"

namespace nc::panel {

static const auto g_MaxTimeRange = 60 * 60 * 24 * 14; // 14 days range for bothering with visits

static std::shared_ptr<const FavoriteLocationsStorage::Location>
Encode( const VFSHost &_host, const std::string &_directory )
{
    auto location = PanelDataPersisency::EncodeLocation( _host, _directory );
    if( !location )
        return nullptr;

    auto v = std::make_shared<FavoriteLocationsStorage::Location>();
    v->hosts_stack = std::move(*location);
    v->verbose_path = PanelDataPersisency::MakeVerbosePathString( _host, _directory );

    return v;
}

FavoriteLocationsStorageImpl::
    FavoriteLocationsStorageImpl( config::Config &_config, const char *_path )
{
    LoadData( _config, _path );

    if( m_Favorites.empty() ) {
        auto ff = FavoriteComposing{*this}.FinderFavorites();
        if( !ff.empty() )
            m_Favorites = move(ff);
        else
            m_Favorites = FavoriteComposing{*this}.DefaultFavorites();
    }
}

std::shared_ptr<const FavoriteLocationsStorage::Location> FavoriteLocationsStorageImpl::
FindInVisitsOrEncode(size_t _footprint,
                     VFSHost &_host,
                     const std::string &_directory)
{
    const auto visit = m_Visits.find(_footprint);
    if( visit != end(m_Visits) )
        return visit->second.location;
    
    return Encode(_host, _directory);
}

void FavoriteLocationsStorageImpl::AddFavoriteLocation( Favorite _favorite )
{
    dispatch_assert_main_queue();
    
    // refresh hash regardless to enforce consistency
    _favorite.footprint = PanelDataPersisency::
        MakeFootprintStringHash( _favorite.location->hosts_stack );
    
    const auto has_already = any_of( begin(m_Favorites), end(m_Favorites), [&](auto &i){
        return i.footprint == _favorite.footprint;
    });
    if( has_already )
        return;

    m_Favorites.emplace_back( std::move(_favorite) );
    FireObservers( FavoritesChanged );
}

std::optional<FavoriteLocationsStorage::Favorite> FavoriteLocationsStorageImpl::
    ComposeFavoriteLocation(VFSHost &_host,
                            const std::string &_directory,
                            const std::string &_title) const
{
    const auto location = Encode(_host, _directory);
    if( !location )
        return std::nullopt;
    
    Favorite f;
    f.location = location;
    f.footprint = _host.FullHashForPath( _directory.c_str() );
    if( _title.empty() ) {
        auto p = boost::filesystem::path( _directory );
        if( p.filename() == "." )
            f.title = p.parent_path().filename().native();
        else
            f.title = p.filename().native();
    }
    else {
        f.title = _title;
    }
    return std::move(f);
}

void FavoriteLocationsStorageImpl::
    ReportLocationVisit( VFSHost &_host, const std::string &_directory )
{
    dispatch_assert_main_queue();
    const auto timestamp = time(nullptr);
    const auto footprint = _host.FullHashForPath( _directory.c_str() );
    
    const auto existing = m_Visits.find(footprint);
    if( existing != end(m_Visits) ) {
        // fastpath - found location, just increment visits cound and refresh last visit time
        existing->second.visits_count++;
        existing->second.last_visit = timestamp;
    }
    else if( auto location = Encode(_host, _directory) ) {
        // slowfast - for the first time we need to encode the visited location
        Visit v;
        v.location = move(location);
        v.last_visit = timestamp;
        v.visits_count = 1;
        m_Visits[footprint] = std::move(v);
    }
}

std::vector< std::shared_ptr<const FavoriteLocationsStorage::Location> >
FavoriteLocationsStorageImpl::FrecentlyUsed( int _amount ) const
{
    dispatch_assert_main_queue();
    if( _amount <= 0 || m_Visits.empty() )
        return {};

    const auto now = time(nullptr);
    const auto last_date = now - g_MaxTimeRange;
    
    auto is_favorite = [this](size_t footprint){ // O(n), n = number of favorites
        return find_if(begin(m_Favorites), end(m_Favorites), [footprint](auto &f){
            return f.footprint == footprint;
         }) != end(m_Favorites);
    };
    
    // visit #, visits count, last visit, frecency score
    std::vector< std::tuple<size_t, int, time_t, float> > recent_visits;
    for( auto &v: m_Visits )
        if( v.second.last_visit > last_date && v.second.visits_count > 0 && !is_favorite(v.first) )
            recent_visits.emplace_back(v.first,
                                       v.second.visits_count,
                                       v.second.last_visit,
                                       0.);

    if( recent_visits.empty() )
        return {};

    const auto max_visits_it = std::max_element
    (std::begin(recent_visits),
     std::end(recent_visits),
     [](auto &l, auto &r){ return std::max(std::get<1>(l), std::get<1>(r)); } );
    const auto max_visits = float(std::get<1>(*max_visits_it));
    
    for( auto &v: recent_visits ) {
        // this is actually not a real frequency, but a normalized value of a visits count.
        const auto frequency = std::get<1>(v) / max_visits; // [0..1]
        const auto recency = 1. - float(now - std::get<2>(v)) / float(g_MaxTimeRange); // [0..1]
        const auto score = frequency + recency; // [0..2]
        std::get<3>(v) = (float)score;
    }

    std::sort( std::begin(recent_visits), std::end(recent_visits), [](auto &_1, auto _2){
        return std::get<3>(_1) > std::get<3>(_2); // sorting in descending order
    });
    
    std::vector< std::shared_ptr<const FavoriteLocationsStorage::Location> > result;
    for( int i = 0, e = std::min(_amount, (int)recent_visits.size()); i != e; ++i )
        result.emplace_back( m_Visits.at(std::get<0>(recent_visits[i])).location );

    return result;
}

std::vector<FavoriteLocationsStorage::Favorite>
FavoriteLocationsStorageImpl::Favorites( /*limit output later*/ ) const
{
    dispatch_assert_main_queue();
    return m_Favorites;
}

config::Value FavoriteLocationsStorageImpl::VisitToJSON(const Visit &_visit)
{
    using namespace rapidjson;
    using namespace nc::config;
    
    Value json(kObjectType);
    
    if( auto l = PanelDataPersisency::LocationToJSON(_visit.location->hosts_stack);
       l.GetType() != kNullType )
        json.AddMember(MakeStandaloneString("location"),
                       std::move(l),
                       g_CrtAllocator );
    else
        return Value{kNullType};
    
    json.AddMember(MakeStandaloneString("visits_count"),
                   Value{_visit.visits_count},
                   g_CrtAllocator );

    json.AddMember(MakeStandaloneString("last_visit"),
                   Value{(int64_t)_visit.last_visit},
                   g_CrtAllocator );

    return json;
}

std::optional<FavoriteLocationsStorageImpl::Visit> FavoriteLocationsStorageImpl::
    JSONToVisit( const config::Value& _json )
{
    if( !_json.IsObject() )
        return std::nullopt;
    
    Visit v;
    
    if( !_json.HasMember("location") )
        return std::nullopt;
    if( auto l = PanelDataPersisency::JSONToLocation(_json["location"]) ) {
        auto location = std::make_shared<Location>();
        location->verbose_path = PanelDataPersisency::MakeVerbosePathString(*l);
        location->hosts_stack = std::move(*l);
        v.location = location;
    }
    else
        return std::nullopt;
    
    if( !_json.HasMember("visits_count") || !_json["visits_count"].IsInt() )
        return std::nullopt;
    v.visits_count = _json["visits_count"].GetInt();
    
    if( !_json.HasMember("last_visit") || !_json["last_visit"].IsInt64() )
        return std::nullopt;
    v.last_visit = _json["last_visit"].GetInt64();
    
    return std::move(v);
}

config::Value FavoriteLocationsStorageImpl::FavoriteToJSON(const Favorite &_favorite)
{
    using namespace rapidjson;
    using namespace nc::config;
    Value json(kObjectType);
    
    if( auto l = PanelDataPersisency::LocationToJSON(_favorite.location->hosts_stack);
       l.GetType()!=kNullType )
        json.AddMember(MakeStandaloneString("location"),
                       std::move(l),
                       g_CrtAllocator );
    else
        return Value{kNullType};
    
    if( !_favorite.title.empty() )
        json.AddMember(MakeStandaloneString("title"),
                       MakeStandaloneString(_favorite.title),
                       g_CrtAllocator );

    return json;
}

std::optional<FavoriteLocationsStorage::Favorite> FavoriteLocationsStorageImpl::
    JSONToFavorite( const config::Value& _json )
{
    if( !_json.IsObject() )
        return std::nullopt;
    
    Favorite f;
    
    if( !_json.HasMember("location") )
        return std::nullopt;
    if( auto l = PanelDataPersisency::JSONToLocation(_json["location"]) ) {
        auto location = std::make_shared<Location>();
        location->verbose_path = PanelDataPersisency::MakeVerbosePathString(*l);
        location->hosts_stack = std::move(*l);
        f.location = location;
    }
    else
        return std::nullopt;

    if( _json.HasMember("title") && _json["title"].IsString() )
        f.title = _json["title"].GetString();
    
    auto fp_string = PanelDataPersisency::MakeFootprintString(f.location->hosts_stack);
    f.footprint = std::hash<std::string>()(fp_string);
    return std::move(f);
}

void FavoriteLocationsStorageImpl::StoreData( config::Config &_config, const char *_path )
{
    dispatch_assert_main_queue();
    using namespace rapidjson;
    using namespace nc::config;
    Value json(kObjectType);
    const auto now = time(nullptr);

    Value manual(kArrayType);
    for( auto &favorite: m_Favorites )
        if( auto v = FavoriteToJSON(favorite); v.GetType() != kNullType )
            manual.PushBack( std::move(v), g_CrtAllocator );

    json.AddMember(MakeStandaloneString("manual"),
                   std::move(manual),
                   g_CrtAllocator );

    Value automatic(kArrayType);
    for( auto &visit: m_Visits )
        if( visit.second.last_visit + g_MaxTimeRange > now )
            if( auto v = VisitToJSON(visit.second); v.GetType() != kNullType )
                automatic.PushBack( std::move(v), g_CrtAllocator );

    json.AddMember(MakeStandaloneString("automatic"),
                   std::move(automatic),
                   g_CrtAllocator );
    
    _config.Set(_path, json);
}

void FavoriteLocationsStorageImpl::LoadData( config::Config &_config, const char *_path )
{
    dispatch_assert_main_queue();
    auto json = _config.Get(_path);
    if( !json.IsObject() )
        return;

    m_Visits.clear();
    m_Favorites.clear();

    if( json.HasMember("automatic") && json["automatic"].IsArray() ) {
        auto &automatic = json["automatic"];
        for( int i = 0, e = automatic.Size(); i != e; ++i )
            if( auto v = JSONToVisit(automatic[i]) ) {
                auto fp_string = PanelDataPersisency::MakeFootprintString(v->location->hosts_stack);
                auto fp = std::hash<std::string>()(fp_string);                
                m_Visits[fp] = std::move( *v );
            }
    }

    if( json.HasMember("manual") && json["manual"].IsArray() ) {
        auto &manual = json["manual"];
        for( int i = 0, e = manual.Size(); i != e; ++i ) {
            if( auto f = JSONToFavorite(manual[i]) )
               m_Favorites.emplace_back( std::move(*f) );
        }
    }
}

void FavoriteLocationsStorageImpl::SetFavorites( const std::vector<Favorite> &_new_favorites )
{
    dispatch_assert_main_queue();
    m_Favorites.clear();
    for( auto &f: _new_favorites ) {
        if( !f.location )
            continue;
        
        Favorite new_favorite = f;
        new_favorite.footprint = PanelDataPersisency::
            MakeFootprintStringHash( new_favorite.location->hosts_stack );
        m_Favorites.emplace_back( std::move(new_favorite) );
    }
    
    FireObservers( FavoritesChanged );
}

FavoriteLocationsStorageImpl::ObservationTicket FavoriteLocationsStorageImpl::
    ObserveFavoritesChanges( std::function<void()> _callback )
{
    return AddObserver( std::move(_callback), FavoritesChanged );
}

void FavoriteLocationsStorageImpl::ClearVisitedLocations()
{
    dispatch_assert_main_queue();
    m_Visits.clear();
}

}
