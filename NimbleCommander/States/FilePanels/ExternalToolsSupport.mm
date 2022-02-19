// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalToolsSupport.h"
#include <Config/Config.h>
#include <Config/RapidJSON.h>
#include <any>
#include <Foundation/Foundation.h>
#include <Utility/StringExtras.h>
#include <Habanero/dispatch_cpp.h>

bool ExternalTool::operator==(const ExternalTool &_rhs) const
{
    return m_Title == _rhs.m_Title && m_ExecutablePath == _rhs.m_ExecutablePath &&
           m_Parameters == _rhs.m_Parameters && m_Shorcut == _rhs.m_Shorcut &&
           m_StartupMode == _rhs.m_StartupMode;
}

bool ExternalTool::operator!=(const ExternalTool &_rhs) const
{
    return !(*this == _rhs);
}

static const auto g_TitleKey = "title";
static const auto g_PathKey = "path";
static const auto g_ParametersKey = "parameters";
static const auto g_ShortcutKey = "shortcut";
static const auto g_StartupKey = "startup";

static nc::config::Value SaveTool(const ExternalTool &_et)
{
    using namespace rapidjson;
    using nc::config::MakeStandaloneString;
    using nc::config::g_CrtAllocator;
    nc::config::Value v(kObjectType);

    v.AddMember(
        MakeStandaloneString(g_TitleKey), MakeStandaloneString(_et.m_Title), g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_PathKey),
                MakeStandaloneString(_et.m_ExecutablePath),
                g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_ParametersKey),
                MakeStandaloneString(_et.m_Parameters),
                g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_ShortcutKey),
                MakeStandaloneString(_et.m_Shorcut.ToPersString()),
                g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_StartupKey),
                nc::config::Value(static_cast<int>(_et.m_StartupMode)),
                g_CrtAllocator);

    return v;
}

static std::optional<ExternalTool> LoadTool(const nc::config::Value &_from)
{
    using namespace rapidjson;
    if( !_from.IsObject() )
        return std::nullopt;

    ExternalTool et;
    if( _from.HasMember(g_PathKey) && _from[g_PathKey].IsString() )
        et.m_ExecutablePath = _from[g_PathKey].GetString();
    else
        return std::nullopt;

    if( _from.HasMember(g_TitleKey) && _from[g_TitleKey].IsString() )
        et.m_Title = _from[g_TitleKey].GetString();

    if( _from.HasMember(g_ParametersKey) && _from[g_ParametersKey].IsString() )
        et.m_Parameters = _from[g_ParametersKey].GetString();

    if( _from.HasMember(g_ShortcutKey) && _from[g_ShortcutKey].IsString() )
        et.m_Shorcut = nc::utility::ActionShortcut(_from[g_ShortcutKey].GetString());

    if( _from.HasMember(g_StartupKey) && _from[g_StartupKey].IsInt() )
        et.m_StartupMode = static_cast<ExternalTool::StartupMode>(_from[g_StartupKey].GetInt());

    return et;
}

ExternalToolsStorage::ExternalToolsStorage(const char *_config_path, nc::config::Config &_config)
    : m_ConfigPath(_config_path), m_Config(_config)
{
    LoadToolsFromConfig();

    m_ConfigObservations.emplace_back(m_Config.Observe(_config_path, [=] {
        LoadToolsFromConfig();
        FireObservers();
    }));
}

void ExternalToolsStorage::LoadToolsFromConfig()
{
    auto tools = m_Config.Get(m_ConfigPath);
    if( !tools.IsArray() )
        return;

    auto lock = std::lock_guard{m_ToolsLock};
    m_Tools.clear();
    for( auto i = tools.Begin(), e = tools.End(); i != e; ++i )
        if( auto et = LoadTool(*i) )
            m_Tools.emplace_back(std::make_shared<ExternalTool>(std::move(*et)));
}

size_t ExternalToolsStorage::ToolsCount() const
{
    auto guard = std::lock_guard{m_ToolsLock};
    return m_Tools.size();
}

std::shared_ptr<const ExternalTool> ExternalToolsStorage::GetTool(size_t _no) const
{
    auto guard = std::lock_guard{m_ToolsLock};
    return _no < m_Tools.size() ? m_Tools[_no] : nullptr;
}

std::vector<std::shared_ptr<const ExternalTool>> ExternalToolsStorage::GetAllTools() const
{
    auto guard = std::lock_guard{m_ToolsLock};
    return m_Tools;
}

ExternalToolsStorage::ObservationTicket
ExternalToolsStorage::ObserveChanges(std::function<void()> _callback)
{
    return AddObserver(move(_callback));
}

void ExternalToolsStorage::WriteToolsToConfig() const
{
    std::vector<std::shared_ptr<const ExternalTool>> tools;
    {
        auto lock = std::lock_guard{m_ToolsLock};
        tools = m_Tools;
    }

    nc::config::Value json_tools{rapidjson::kArrayType};
    for( auto &t : tools )
        json_tools.PushBack(SaveTool(*t), nc::config::g_CrtAllocator);
    m_Config.Set(m_ConfigPath, json_tools);
}

void ExternalToolsStorage::CommitChanges()
{
    FireObservers();
    dispatch_to_background([=] { WriteToolsToConfig(); });
}

void ExternalToolsStorage::ReplaceTool(ExternalTool _tool, size_t _at_index)
{
    {
        auto lock = std::lock_guard{m_ToolsLock};
        if( _at_index >= m_Tools.size() )
            return;
        if( *m_Tools[_at_index] == _tool )
            return; // do nothing if _tool is equal
        m_Tools[_at_index] = std::make_shared<ExternalTool>(std::move(_tool));
    }
    CommitChanges();
}

void ExternalToolsStorage::InsertTool(ExternalTool _tool)
{
    {
        auto lock = std::lock_guard{m_ToolsLock};
        m_Tools.emplace_back(std::make_shared<ExternalTool>(std::move(_tool)));
    }
    CommitChanges();
}

void ExternalToolsStorage::MoveTool(const size_t _at_index, const size_t _to_index)
{
    if( _at_index == _to_index )
        return;

    {
        auto lock = std::lock_guard{m_ToolsLock};
        if( _at_index >= m_Tools.size() || _to_index >= m_Tools.size() )
            return;
        auto v = m_Tools[_at_index];
        m_Tools.erase(next(begin(m_Tools), _at_index));
        m_Tools.insert(next(begin(m_Tools), _to_index), v);
    }

    CommitChanges();
}

void ExternalToolsStorage::RemoveTool(size_t _at_index)
{
    {
        auto lock = std::lock_guard{m_ToolsLock};
        if( _at_index >= m_Tools.size() )
            return;

        m_Tools.erase(next(begin(m_Tools), _at_index));
    }
    CommitChanges();
}
