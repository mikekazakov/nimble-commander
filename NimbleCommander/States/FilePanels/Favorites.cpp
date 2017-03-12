#include <CoreServices/CoreServices.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include "Favorites.h"

//#include "Views/MainWndGoToButton.h"

//static size_t HashForPath( const VFSHostPtr &_at_vfs, const string &_path )
//{
//    string full;
//    auto c = _at_vfs;
//    while( c ) {
//        // we need to incorporate options somehow here. or not?
//        string part = string(c->Tag) + string(c->JunctionPath()) + "|";
//        full.insert(0, part);
//        c = c->Parent();
//    }
//    full += _path;
//    return hash<string>()(full);
//}

static const auto g_MaxTimeRange = 60 * 60 * 24 * 14; // 14 days range for bothering with visits

static vector<string> GetFindersFavorites();
static vector<string> GetDefaultFavorites();

static string ensure_tr_slash( string _str )
{
    if( _str.empty() || _str.back() != '/' )
        _str += '/';
    return _str;
}

static size_t HashForPath( const VFSHost &_at_vfs, const string &_path )
{
    constexpr auto max_depth = 32;
    array<const VFSHost*, max_depth> hosts;
    int hosts_n = 0;

    auto cur = &_at_vfs;
    while( cur && hosts_n < max_depth ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    char buf[4096] = "";
    while( hosts_n > 0 ) {
        auto &host = *hosts[--hosts_n];
        strcat( buf, host.FSTag() );
        strcat( buf, "|" );
        strcat( buf, host.Configuration().VerboseJunction() );
        strcat( buf, "|" );
    }
    strcat( buf, _path.c_str() );

//    cout << buf << endl;

    return hash<string_view>()(buf);
}

//    result.emplace_back(url());
//    result.emplace_back(url(CommonPaths::Desktop()));
//    result.emplace_back(url());
//    result.emplace_back(url());
//    result.emplace_back(url());
//    result.emplace_back(url());
//    result.emplace_back(url());


// TODO: footprint from persistant presentation


static string VerbosePath( const VFSHost &_host, const string &_directory )
{
    array<const VFSHost*, 32> hosts;
    int hosts_n = 0;

    auto cur = &_host;
    while( cur ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    string s;
    while(hosts_n > 0)
        s += hosts[--hosts_n]->Configuration().VerboseJunction();
    s += _directory;
    if(s.back() != '/') s += '/';
    return s;
}

static shared_ptr<const FavoriteLocationsStorage::Location>
Encode( const VFSHost &_host, const string &_directory )
{
    auto location = PanelDataPersisency::EncodeLocation( _host, _directory );
    if( !location )
        return nullptr;

    auto v = make_shared<FavoriteLocationsStorage::Location>();
    v->hosts_stack = move(*location);
    v->verbose_path = VerbosePath( _host, _directory );

    return v;
}

struct FavoriteLocationsStorage::Visit
{
    shared_ptr<const Location>  location;
    int                         visits_count = 0;
    time_t                      last_visit = 0;
};

FavoriteLocationsStorage::FavoriteLocationsStorage( GenericConfig &_config, const char *_path )
{
    LoadData( _config, _path );

//    AddFavoriteLocation(<#VFSHost &_host#>, <#const string &_directory#>)

//    for( auto &p: DefaultFavorites() )
    if( m_Favorites.empty() )
        for( auto &p: GetFindersFavorites() )
            AddFavoriteLocation( *VFSNativeHost::SharedHost(), p );
}

void FavoriteLocationsStorage::AddFavoriteLocation(VFSHost &_host,
                                                   const string &_directory,
                                                   const string &_filename,
                                                   const string &_title)
{
    const auto footprint = HashForPath( _host, _directory );
//    const auto visit = find_if( begin(m_Visits), end(m_Visits), [footprint](auto &i){
//        return i.footprint == footprint;
//    });
    shared_ptr<const Location> location_ptr;
    const auto visit = m_Visits.find(footprint);
    if( visit != end(m_Visits) )
        location_ptr =visit->second.location;
    else {
        if( auto location = Encode(_host, _directory) ) {
            location_ptr = location;
        }
        else
            return;
    }
    
    
//    if( visit == end(m_Visits) ) {
//        if( auto location = Encode(_host, _directory) ) {
//            Visit v;
//            v.location = location;
//            location_ptr = location;
////            v.footprint = footprint;
////            m_Visits.emplace_back( move(v) );
//            m_Visits[footprint] = move(v);
//        }
//    }
//    else
//        location_ptr = visit->second.location;
    
    const auto favorite = find_if( begin(m_Favorites), end(m_Favorites), [&](auto &i){
        return i.footprint == footprint;
    });
    if( favorite == end(m_Favorites) ) {
        Favorite f;
        f.location = location_ptr;
        f.footprint = footprint;
        f.filename = _filename;
        f.title = _title;
        
//        cout << "manual: " << f.location->verbose_path << " - " << footprint << endl;
        
        m_Favorites.emplace_back( move(f) );
    }
}

void FavoriteLocationsStorage::ReportLocationVisit( VFSHost &_host, const string &_directory )
{
    const auto timestamp = time(nullptr);
    const auto footprint = HashForPath( _host, _directory );
    
    // O(n), n = number of different locations visited
//    const auto existing = find_if( begin(m_Visits), end(m_Visits), [footprint](auto &i){
//        return i.footprint == footprint;
//    });
    const auto existing = m_Visits.find(footprint);
    
    if( existing != end(m_Visits) ) {
        // fastpath - find location, increment visits cound and refresh last visit time
        existing->second.visits_count++;
        existing->second.last_visit = timestamp;
//        cout << footprint << " - " << existing->visits_count << endl;
    }
    else if( auto location = Encode(_host, _directory) ) {
        Visit v;
        
//        if( auto l = PanelDataPersisency::EncodeLocation(_host, _directory) ) {
////            v.host_stack2 = move(*l);
//            auto fp = PanelDataPersisency::MakeFootprintString(*l);
//            cout << fp << endl;
//            cout << footprint << " - " << hash<string>()(fp) << endl;
//        }
        
        
        v.location = move(location);
//        v.footprint = footprint;
        v.last_visit = timestamp;
        v.visits_count = 1;
//        cout << "new: " << v.location->verbose_path << footprint << endl;


//        m_Visits.emplace_back( move(v) );
        m_Visits[footprint] = move(v);
    }
    
    
//    auto fr = FrecentlyUsed(10);
//    cout << "-----------------" << endl;
//    for(auto &i: fr)
//        cout << i->verbose_path << endl;
//    cout << endl;
}

vector< shared_ptr<const FavoriteLocationsStorage::Location> >
FavoriteLocationsStorage::FrecentlyUsed( int _amount ) const
{
    if( _amount <= 0 )
        return {};

    const auto now = time(nullptr);
    const auto last_date = now - g_MaxTimeRange;
    
    auto is_favorite = [this](size_t footprint){ // O(n), n = number of favorites
        return find_if(begin(m_Favorites), end(m_Favorites), [footprint](auto &f){
            return f.footprint == footprint;
         }) != end(m_Favorites);
    };
    
    // location, visits count, last visit, frecency score
    vector< tuple<shared_ptr<const Location>, int, time_t, double> > recent_visits;
    for( auto &v: m_Visits )
        if( v.second.last_visit > last_date && v.second.visits_count > 0 && !is_favorite(v.first) )
            recent_visits.emplace_back(v.second.location,
                                       v.second.visits_count,
                                       v.second.last_visit,
                                       0.);
    
    const auto total_visits = accumulate(
        begin(recent_visits),
        end(recent_visits),
        1, // a little offset to exclude possibility of division by zero
        [](auto &l, auto &r) { return l + get<1>(r); }
        );
    
    for( auto &v: recent_visits ) {
        const auto frequency = double(get<1>(v)) / double(total_visits); // [0..1]
        const auto recency = 1. - double(now - get<2>(v)) / double(g_MaxTimeRange); // [0..1]
        const auto score = frequency + recency; // [0..2]
        get<3>(v) = score;
    }

    sort( begin(recent_visits), end(recent_visits), [](auto &_1, auto _2){
        return get<3>(_1) > get<3>(_2); // sorting in descending order
    });
    
    vector< shared_ptr<const FavoriteLocationsStorage::Location> > result;
    for( int i = 0, e = min(_amount, (int)recent_visits.size()); i != e; ++i ) {
//        cout << get<0>(recent_visits[i])->verbose_path << ": " << get<3>(recent_visits[i]) << endl;
        result.emplace_back( get<0>(recent_visits[i]) );
    }

    return result;
}

vector<FavoriteLocationsStorage::Favorite>
FavoriteLocationsStorage::Favorites( /*limit output later*/ ) const
{
    return m_Favorites;
}

optional<rapidjson::StandaloneValue> FavoriteLocationsStorage::VisitToJSON(const Visit &_visit)
{
    using namespace rapidjson;
    StandaloneValue json(kObjectType);
    
    if( auto l = PanelDataPersisency::LocationToJSON(_visit.location->hosts_stack) )
        json.AddMember(MakeStandaloneString("location"),
                       move(*l),
                       g_CrtAllocator );
    else
        return nullopt;
    
    json.AddMember(MakeStandaloneString("visits_count"),
                   StandaloneValue{_visit.visits_count},
                   g_CrtAllocator );

    json.AddMember(MakeStandaloneString("last_visit"),
                   StandaloneValue{(int64_t)_visit.last_visit},
                   g_CrtAllocator );

    return move(json);
}

optional<FavoriteLocationsStorage::Visit> FavoriteLocationsStorage::
JSONToVisit( const rapidjson::StandaloneValue& _json )
{
    if( !_json.IsObject() )
        return nullopt;
    
    Visit v;
    
    if( !_json.HasMember("location") )
        return nullopt;
    if( auto l = PanelDataPersisency::JSONToLocation(_json["location"]) ) {
        auto location = make_shared<Location>();
        location->verbose_path = PanelDataPersisency::MakeVerbosePathString(*l);
        location->hosts_stack = move(*l);
        v.location = location;
    }
    else
        return nullopt;
    
    if( !_json.HasMember("visits_count") || !_json["visits_count"].IsInt() )
        return nullopt;
    v.visits_count = _json["visits_count"].GetInt();
    
    if( !_json.HasMember("last_visit") || !_json["last_visit"].IsInt64() )
        return nullopt;
    v.last_visit = _json["last_visit"].GetInt64();
    
    return move(v);
}

optional<rapidjson::StandaloneValue> FavoriteLocationsStorage::
FavoriteToJSON(const Favorite &_favorite)
{
  using namespace rapidjson;
    StandaloneValue json(kObjectType);
    
    if( auto l = PanelDataPersisency::LocationToJSON(_favorite.location->hosts_stack) )
        json.AddMember(MakeStandaloneString("location"),
                       move(*l),
                       g_CrtAllocator );
    else
        return nullopt;
    
    if( !_favorite.title.empty() )
        json.AddMember(MakeStandaloneString("title"),
                       MakeStandaloneString(_favorite.title),
                       g_CrtAllocator );

    if( !_favorite.filename.empty() )
        json.AddMember(MakeStandaloneString("filename"),
                       MakeStandaloneString(_favorite.filename),
                       g_CrtAllocator );

    return move(json);
}

void FavoriteLocationsStorage::StoreData( GenericConfig &_config, const char *_path )
{
    using namespace rapidjson;
    StandaloneValue json(kObjectType);
    const auto now = time(nullptr);

    StandaloneValue manual(kArrayType);
    for( auto &favorite: m_Favorites )
        if( auto v = FavoriteToJSON(favorite) )
            manual.PushBack( move(*v), rapidjson::g_CrtAllocator );

    json.AddMember(MakeStandaloneString("manual"),
                   move(manual),
                   g_CrtAllocator );

    StandaloneValue automatic(kArrayType);
    for( auto &visit: m_Visits )
        if( visit.second.last_visit + g_MaxTimeRange > now )
            if( auto v = VisitToJSON(visit.second) )
                automatic.PushBack( move(*v), rapidjson::g_CrtAllocator );

    json.AddMember(MakeStandaloneString("automatic"),
                   move(automatic),
                   g_CrtAllocator );
    
    _config.Set(_path, json);
}

void FavoriteLocationsStorage::LoadData( GenericConfig &_config, const char *_path )
{
    auto json = _config.Get(_path);
    if( !json.IsObject() )
        return;

    if( json.HasMember("automatic") && json["automatic"].IsArray() ) {
        auto &automatic = json["automatic"];
        for( int i = 0, e = automatic.Size(); i != e; ++i )
            if( auto v = JSONToVisit(automatic[i]) ) {
                auto fp_string = PanelDataPersisency::MakeFootprintString(v->location->hosts_stack);
                auto fp = hash<string>()(fp_string);
                
//                cout << "automatic: " << fp_string << " - " << fp << endl;
                
                m_Visits[fp] = move( *v );
            }
    }
}

static string StringFromURL( CFURLRef _url )
{
    char path_buf[MAXPATHLEN];
    if( CFURLGetFileSystemRepresentation(_url, true, (UInt8*)path_buf, MAXPATHLEN) )
        return path_buf;
    return {};
}

static vector<string> GetFindersFavorites()
{
    const auto flags = kLSSharedFileListNoUserInteraction|kLSSharedFileListDoNotMountVolumes;
    vector<string> paths;
    
    UInt32 seed;
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListFavoriteItems, NULL);
    CFArrayRef snapshot = LSSharedFileListCopySnapshot(list, &seed);
    if( snapshot ) {
        for( int i = 0, e = (int)CFArrayGetCount(snapshot); i != e; ++i ) {
            if( auto item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(snapshot, i) ) {
                CFErrorRef err = nullptr;
                auto url = LSSharedFileListItemCopyResolvedURL(item, flags, &err);
                if( url ) {
                    auto path = StringFromURL( url );
                    if( !path.empty() &&
                        !has_suffix(path, ".cannedSearch") &&
                        !has_suffix(path, ".cannedSearch/") &&
                        !has_suffix(path, ".savedSearch") &&
                        VFSNativeHost::SharedHost()->IsDirectory(path.c_str(), 0) )
                        paths.emplace_back( ensure_tr_slash( move(path) ) );
                    CFRelease(url);
                }
                if( err ) {
                    if( auto description = CFErrorCopyDescription(err) ) {
                        CFShow(description);
                        CFRelease(description);
                    }
                    if( auto reason = CFErrorCopyFailureReason(err) ) {
                        CFShow(reason);
                        CFRelease(reason);
                    }
                    CFRelease(err);
                }
            }
        }
        CFRelease(snapshot);
    }
    CFRelease(list);
    
    return paths;
}

static vector<string> GetDefaultFavorites()
{
    return {{
        CommonPaths::Home(),
        CommonPaths::Desktop(),
        CommonPaths::Documents(),
        CommonPaths::Downloads(),
        CommonPaths::Movies(),
        CommonPaths::Music(),
        CommonPaths::Pictures()
    }};
}
