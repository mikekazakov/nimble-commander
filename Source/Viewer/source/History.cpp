// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "History.h"
#include <Config/RapidJSON.h>
#include <Utility/Encodings.h>
#include <algorithm>

static const auto g_ConfigMaximumHistoryEntries = "viewer.maximumHistoryEntries";
static const auto g_ConfigSaveFileEnconding = "viewer.saveFileEncoding";
static const auto g_ConfigSaveFileMode = "viewer.saveFileMode";
static const auto g_ConfigSaveFilePosition = "viewer.saveFilePosition";
static const auto g_ConfigSaveFileWrapping = "viewer.saveFileWrapping";
static const auto g_ConfigSaveFileSelection = "viewer.saveFileSelection";
static const auto g_ConfigSaveFileLanguage = "viewer.saveFileLanguage";

namespace nc::viewer {

static nc::config::Value EntryToJSONObject(const History::Entry &_entry)
{
    using namespace nc::config;
    Value o(rapidjson::kObjectType);
    o.AddMember("path", MakeStandaloneString(_entry.path), g_CrtAllocator);
    o.AddMember("position", Value(_entry.position), g_CrtAllocator);
    o.AddMember("wrapping", Value(_entry.wrapping), g_CrtAllocator);
    o.AddMember("mode", Value(static_cast<int>(_entry.view_mode)), g_CrtAllocator);
    o.AddMember("encoding", MakeStandaloneString(utility::NameFromEncoding(_entry.encoding)), g_CrtAllocator);
    o.AddMember("selection_loc", Value(static_cast<int64_t>(_entry.selection.location)), g_CrtAllocator);
    o.AddMember("selection_len", Value(static_cast<int64_t>(_entry.selection.length)), g_CrtAllocator);
    if( _entry.language ) {
        o.AddMember("language", MakeStandaloneString(_entry.language.value()), g_CrtAllocator);
    }
    return o;
}

static std::optional<History::Entry> JSONObjectToEntry(const nc::config::Value &_object)
{
    using namespace rapidjson;
    auto has_string = [&](const char *_key) { return _object.HasMember(_key) && _object[_key].IsString(); };
    auto has_number = [&](const char *_key) { return _object.HasMember(_key) && _object[_key].IsNumber(); };
    auto has_bool = [&](const char *_key) { return _object.HasMember(_key) && _object[_key].IsBool(); };

    History::Entry e;

    if( _object.GetType() != kObjectType )
        return std::nullopt;

    if( !has_string("path") )
        return std::nullopt;

    e.path = _object["path"].GetString();

    if( has_number("position") )
        e.position = _object["position"].GetInt64();

    if( has_bool("wrapping") )
        e.wrapping = _object["wrapping"].GetBool();

    if( has_number("mode") )
        e.view_mode = static_cast<ViewMode>(_object["mode"].GetInt());

    if( has_string("encoding") )
        e.encoding = utility::EncodingFromName(_object["encoding"].GetString());

    if( has_number("selection_loc") && has_number("selection_len") ) {
        e.selection.location = _object["selection_loc"].GetInt64();
        e.selection.length = _object["selection_len"].GetInt64();
    }

    if( has_string("language") ) {
        e.language = _object["language"].GetString();
    }

    return e;
}

History::History(nc::config::Config &_global_config, nc::config::Config &_state_config, const char *_config_path)
    : m_GlobalConfig(_global_config), m_StateConfig(_state_config), m_StateConfigPath(_config_path)
{
    m_Limit = std::clamp(m_GlobalConfig.GetInt(g_ConfigMaximumHistoryEntries), 0, 4096);

    LoadSaveOptions();
    m_GlobalConfig.ObserveMany(
        m_ConfigObservations,
        [this] { LoadSaveOptions(); },
        std::initializer_list<const char *>{g_ConfigSaveFileEnconding,
                                            g_ConfigSaveFileMode,
                                            g_ConfigSaveFilePosition,
                                            g_ConfigSaveFileWrapping,
                                            g_ConfigSaveFileSelection,
                                            g_ConfigSaveFileLanguage});
    LoadFromStateConfig();
}

void History::AddEntry(Entry _entry)
{
    auto lock = std::lock_guard{m_HistoryLock};
    auto it = std::ranges::find_if(m_History, [&](auto &_i) { return _i.path == _entry.path; });
    if( it != std::end(m_History) )
        m_History.erase(it);
    m_History.push_front(std::move(_entry));

    while( m_History.size() >= m_Limit )
        m_History.pop_back();
}

std::optional<History::Entry> History::EntryByPath(const std::string &_path) const
{
    auto lock = std::lock_guard{m_HistoryLock};
    auto it = std::ranges::find_if(m_History, [&](auto &_i) { return _i.path == _path; });
    if( it != std::end(m_History) )
        return *it;
    return std::nullopt;
}

void History::LoadSaveOptions()
{
    m_Options.encoding = m_GlobalConfig.GetBool(g_ConfigSaveFileEnconding);
    m_Options.mode = m_GlobalConfig.GetBool(g_ConfigSaveFileMode);
    m_Options.position = m_GlobalConfig.GetBool(g_ConfigSaveFilePosition);
    m_Options.wrapping = m_GlobalConfig.GetBool(g_ConfigSaveFileWrapping);
    m_Options.selection = m_GlobalConfig.GetBool(g_ConfigSaveFileSelection);
    m_Options.language = m_GlobalConfig.GetBool(g_ConfigSaveFileLanguage);
}

History::SaveOptions History::Options() const
{
    return m_Options;
}

bool History::Enabled() const
{
    auto options = Options();
    return options.encoding || options.mode || options.position || options.wrapping || options.selection ||
           options.language;
}

void History::SaveToStateConfig() const
{
    nc::config::Value entries(rapidjson::kArrayType);
    {
        auto lock = std::lock_guard{m_HistoryLock};
        for( auto &e : m_History ) {
            auto o = EntryToJSONObject(e);
            if( o.GetType() != rapidjson::kNullType )
                entries.PushBack(std::move(o), nc::config::g_CrtAllocator);
        }
    }
    m_StateConfig.Set(m_StateConfigPath, entries);
}

void History::LoadFromStateConfig()
{
    using namespace rapidjson;
    auto entries = m_StateConfig.Get(m_StateConfigPath);
    auto lock = std::lock_guard{m_HistoryLock};
    if( entries.GetType() == kArrayType ) {
        for( auto i = entries.Begin(), e = entries.End(); i != e; ++i )
            if( auto c = JSONObjectToEntry(*i) )
                m_History.emplace_back(*c);
    }
}

void History::ClearHistory()
{
    auto lock = std::lock_guard{m_HistoryLock};
    m_History.clear();
}

} // namespace nc::viewer
