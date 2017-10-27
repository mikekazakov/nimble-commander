// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Core/rapidjson.h"
#include "InternalViewerHistory.h"

static const auto g_StatePath                   = "viewer.history";
static const auto g_ConfigMaximumHistoryEntries = "viewer.maximumHistoryEntries";
static const auto g_ConfigSaveFileEnconding     = "viewer.saveFileEncoding";
static const auto g_ConfigSaveFileMode          = "viewer.saveFileMode";
static const auto g_ConfigSaveFilePosition      = "viewer.saveFilePosition";
static const auto g_ConfigSaveFileWrapping      = "viewer.saveFileWrapping";
static const auto g_ConfigSaveFileSelection     = "viewer.saveFileSelection";

static GenericConfig::ConfigValue EntryToJSONObject( const InternalViewerHistory::Entry &_entry )
{
    GenericConfig::ConfigValue o(rapidjson::kObjectType);
    o.AddMember("path", rapidjson::MakeStandaloneString(_entry.path), GenericConfig::g_CrtAllocator);
    o.AddMember("position", GenericConfig::ConfigValue(_entry.position), GenericConfig::g_CrtAllocator);
    o.AddMember("wrapping", GenericConfig::ConfigValue(_entry.wrapping), GenericConfig::g_CrtAllocator);
    o.AddMember("mode", GenericConfig::ConfigValue((int)_entry.view_mode), GenericConfig::g_CrtAllocator);
    o.AddMember("encoding", rapidjson::MakeStandaloneString(encodings::NameFromEncoding(_entry.encoding)), GenericConfig::g_CrtAllocator);
    o.AddMember("selection_loc", GenericConfig::ConfigValue((int64_t)_entry.selection.location), GenericConfig::g_CrtAllocator);
    o.AddMember("selection_len", GenericConfig::ConfigValue((int64_t)_entry.selection.length), GenericConfig::g_CrtAllocator);
    return o;
}

static optional<InternalViewerHistory::Entry> JSONObjectToEntry( const GenericConfig::ConfigValue &_object )
{
    using namespace rapidjson;    
    auto has_string = [&](const char *_key){ return _object.HasMember(_key) && _object[_key].IsString(); };
    auto has_number = [&](const char *_key){ return _object.HasMember(_key) && _object[_key].IsNumber(); };
    auto has_bool   = [&](const char *_key){ return _object.HasMember(_key) && _object[_key].IsBool(); };
    
    InternalViewerHistory::Entry e;
    
    if( _object.GetType() != kObjectType )
        return nullopt;
    
    if( !has_string("path") )
        return nullopt;
    
    e.path = _object["path"].GetString();
    
    if( has_number("position") )
        e.position = _object["position"].GetInt64();
    
    if( has_bool("wrapping") )
        e.wrapping = _object["wrapping"].GetBool();

    if( has_number("mode") )
        e.view_mode = (BigFileViewModes)_object["mode"].GetInt();
    
    if( has_string("encoding") )
        e.encoding = encodings::EncodingFromName( _object["encoding"].GetString() );

    if( has_number("selection_loc") && has_number("selection_len") ) {
        e.selection.location = _object["selection_loc"].GetInt64();
        e.selection.length = _object["selection_len"].GetInt64();
    }
    
    return e;
}

InternalViewerHistory::InternalViewerHistory( GenericConfig &_state_config, const char *_config_path ):
    m_StateConfig(_state_config),
    m_StateConfigPath(_config_path),
    m_Limit( max(0, min(GlobalConfig().GetInt(g_ConfigMaximumHistoryEntries), 4096)) )
{
    // Wire up notification about application shutdown
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
                                                    SaveToStateConfig();
                                                }];
    LoadSaveOptions();
    GlobalConfig().ObserveMany(m_ConfigObservations,
                               [=]{ LoadSaveOptions(); },
                               initializer_list<const char *>{
                                   g_ConfigSaveFileEnconding,
                                   g_ConfigSaveFileMode,
                                   g_ConfigSaveFilePosition,
                                   g_ConfigSaveFileWrapping,
                                   g_ConfigSaveFileSelection}
                               );    
    LoadFromStateConfig();
}

InternalViewerHistory& InternalViewerHistory::Instance()
{
    static auto history = new InternalViewerHistory( StateConfig(), g_StatePath );
    return *history;
}

void InternalViewerHistory::AddEntry( Entry _entry )
{
    LOCK_GUARD(m_HistoryLock) {
        auto it = find_if( begin(m_History), end(m_History), [&](auto &_i){
            return _i.path == _entry.path;
        });
        if( it != end(m_History) )
            m_History.erase(it);
        m_History.push_front( move(_entry) );
        
        while( m_History.size() >= m_Limit )
            m_History.pop_back();
    }
}

optional<InternalViewerHistory::Entry> InternalViewerHistory::EntryByPath( const string &_path ) const
{
    LOCK_GUARD(m_HistoryLock) {
        auto it = find_if( begin(m_History), end(m_History), [&](auto &_i){
            return _i.path == _path;
        });
        if( it != end(m_History) )
            return *it;
    }
    return nullopt;
}

void InternalViewerHistory::LoadSaveOptions()
{
    m_Options.encoding    = GlobalConfig().GetBool(g_ConfigSaveFileEnconding);
    m_Options.mode        = GlobalConfig().GetBool(g_ConfigSaveFileMode);
    m_Options.position    = GlobalConfig().GetBool(g_ConfigSaveFilePosition);
    m_Options.wrapping    = GlobalConfig().GetBool(g_ConfigSaveFileWrapping);
    m_Options.selection   = GlobalConfig().GetBool(g_ConfigSaveFileSelection);
}

InternalViewerHistory::SaveOptions InternalViewerHistory::Options() const
{
    return m_Options;
}

bool InternalViewerHistory::Enabled() const
{
    auto options = Options();
    return options.encoding || options.mode || options.position || options.wrapping || options.selection;
}

void InternalViewerHistory::SaveToStateConfig() const
{
    GenericConfig::ConfigValue entries(rapidjson::kArrayType);
    LOCK_GUARD(m_HistoryLock) {
        for(auto &e: m_History) {
            auto o = EntryToJSONObject(e);
            if( o.GetType() != rapidjson::kNullType )
                entries.PushBack( move(o), GenericConfig::g_CrtAllocator );
        }
    }
    m_StateConfig.Set(m_StateConfigPath, entries);
}

void InternalViewerHistory::LoadFromStateConfig()
{
    using namespace rapidjson;
    auto entries = m_StateConfig.Get(m_StateConfigPath);
    LOCK_GUARD(m_HistoryLock) {
        if( entries.GetType() == kArrayType ) {
            for( auto i = entries.Begin(), e = entries.End(); i != e; ++i )
                if( auto c = JSONObjectToEntry(*i) )
                    m_History.emplace_back( *c );
        }
    }
}

void InternalViewerHistory::ClearHistory()
{
    LOCK_GUARD(m_HistoryLock)
        m_History.clear();
}
