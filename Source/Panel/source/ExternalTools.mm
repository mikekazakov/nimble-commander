// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalTools.h"
#include "Internal.h"
#include <Config/Config.h>
#include <Config/RapidJSON.h>
#include <Foundation/Foundation.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <Term/Task.h>
#include <Base/dispatch_cpp.h>
#include <Base/UnorderedUtil.h>
#include <VFS/VFSError.h>
#include <fmt/core.h>
#include <any>
#include <atomic>
#include <filesystem>
#include <algorithm>
#include <sys/stat.h>

namespace nc::panel {

using namespace std::literals;

static const auto g_TitleKey = "title";
static const auto g_PathKey = "path";
static const auto g_ParametersKey = "parameters";
static const auto g_ShortcutKey = "shortcut";
static const auto g_StartupKey = "startup";
static const auto g_UUIDKey = "uuid";

ExternalToolsParameters::Step::Step(ActionType _type, uint16_t _index, bool _partial)
    : type(_type), index(_index), partial(_partial)
{
}

void ExternalToolsParameters::InsertUserDefinedText(UserDefined _ud, bool _partial)
{
    m_Steps.emplace_back(ActionType::UserDefined, m_UserDefined.size(), _partial);
    m_UserDefined.emplace_back(std::move(_ud));
}

void ExternalToolsParameters::InsertValueRequirement(EnterValue _ev, bool _partial)
{
    m_Steps.emplace_back(ActionType::EnterValue, m_EnterValues.size(), _partial);
    m_EnterValues.emplace_back(std::move(_ev));
}

void ExternalToolsParameters::InsertCurrentItem(CurrentItem _ci, bool _partial)
{
    m_Steps.emplace_back(ActionType::CurrentItem, m_CurrentItems.size(), _partial);
    m_CurrentItems.emplace_back(_ci);
}

void ExternalToolsParameters::InsertSelectedItem(SelectedItems _si, bool _partial)
{
    m_Steps.emplace_back(ActionType::SelectedItems, m_SelectedItems.size(), _partial);
    m_SelectedItems.emplace_back(_si);
}

std::span<const ExternalToolsParameters::Step> ExternalToolsParameters::Steps() const noexcept
{
    return m_Steps;
}

const ExternalToolsParameters::Step &ExternalToolsParameters::StepNo(size_t _number) const
{
    return m_Steps.at(_number);
}

size_t ExternalToolsParameters::StepsAmount() const
{
    return m_Steps.size();
}

const ExternalToolsParameters::UserDefined &ExternalToolsParameters::GetUserDefined(size_t _index) const
{
    return m_UserDefined.at(_index);
}

const ExternalToolsParameters::EnterValue &ExternalToolsParameters::GetEnterValue(size_t _index) const
{
    return m_EnterValues.at(_index);
}

const ExternalToolsParameters::CurrentItem &ExternalToolsParameters::GetCurrentItem(size_t _index) const
{
    return m_CurrentItems.at(_index);
}

const ExternalToolsParameters::SelectedItems &ExternalToolsParameters::GetSelectedItems(size_t _index) const
{
    return m_SelectedItems.at(_index);
}

unsigned ExternalToolsParameters::GetMaximumTotalFiles() const
{
    return m_MaximumTotalFiles;
}

namespace {

struct InterpretInvertFlag {
};
struct SetMaximumFilesFlag {
    unsigned maximum = 0;
};

using ParametersVariant = std::variant<ExternalToolsParameters::UserDefined,
                                       ExternalToolsParameters::EnterValue,
                                       ExternalToolsParameters::CurrentItem,
                                       ExternalToolsParameters::SelectedItems,
                                       SetMaximumFilesFlag>;

} // namespace

static std::expected<std::vector<std::pair<ParametersVariant, bool>>, std::string>
Eat(const std::string_view _source) noexcept
{
    std::string_view source = _source;
    std::string_view prev;
    std::optional<std::string> user_defined;
    std::vector<std::pair<ParametersVariant, bool>> result;
    bool left_right = false; // default is source/dest
    std::optional<unsigned> number;
    std::optional<std::string> prompt;
    bool placeholder = false;
    bool minus = false;
    bool list = false;
    bool in_prompt = false;

    auto error = [&] {
        const auto error_pos = prev.data() - _source.data();
        return std::unexpected(
            fmt::format("Parse error:\n{}⚠️{}", _source.substr(0, error_pos), _source.substr(error_pos)));
    };
    auto reset_placeholder = [&] {
        number.reset();
        prompt.reset();
        placeholder = minus = list = in_prompt = false;
    };
    auto location = [&] {
        if( left_right )
            return minus ? ExternalToolsParameters::Location::Right : ExternalToolsParameters::Location::Left;
        else
            return minus ? ExternalToolsParameters::Location::Target : ExternalToolsParameters::Location::Source;
    };

    while( !source.empty() ) {
        prev = source;
        char c;
        bool escaped = false;
        if( source[0] == '\\' && source.length() > 1 ) {
            c = source[1];
            escaped = true;
            source.remove_prefix(2);
        }
        else if( source[0] == '%' && source.length() > 1 && source[1] == '%' ) {
            c = '%';
            escaped = true;
            source.remove_prefix(2);
        }
        else {
            c = source[0];
            source.remove_prefix(1);
        }

        if( user_defined != std::nullopt && (c == '%' || c == ' ') && !escaped ) {
            // flush existing arg and continue parsing
            result.emplace_back(ExternalToolsParameters::UserDefined{std::move(*user_defined)}, true);
            user_defined.reset();
        }

        if( user_defined != std::nullopt ) {
            *user_defined += c;
            continue;
        }

        if( in_prompt ) {
            // continuing or ending user prompt
            if( c == '"' )
                in_prompt = false;
            else
                *prompt += c;
            continue;
        }

        if( c == '%' && !placeholder && !escaped ) {
            // start ..%something..
            placeholder = true;
            continue;
        }
        if( c == '%' && placeholder ) {
            // guard against ..%5%p...
            return error();
        }

        if( placeholder ) {
            if( c >= '0' && c <= '9' ) {
                number = (number.value_or(0) * 10) + c - '0';
                continue;
            }

            if( c == '-' ) {
                if( minus || number )
                    return error(); // guard against %--, %50-
                minus = true;
                continue;
            }

            if( c == 'L' ) {
                if( list || number || prompt )
                    return error(); // guard agains %42L, %LL, %"salve"L
                list = true;
                continue;
            }

            if( c == '"' ) {
                if( minus || number )
                    return error(); // guard against %-" and %42"
                prompt.emplace();
                in_prompt = true;
                continue;
            }

            if( c == '?' ) { // terminal - ask the user for a parameter
                if( minus || number || list )
                    return error(); // malformed string, aborting
                result.emplace_back(ExternalToolsParameters::EnterValue{prompt ? std::move(*prompt) : std::string{}},
                                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'r' ) { // terminal - directory path
                if( prompt || number || list )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::CurrentItem{.location = location(),
                                                         .what = ExternalToolsParameters::FileInfo::DirectoryPath},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'p' ) { // terminal - current path
                if( prompt || number || list )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::CurrentItem{.location = location(),
                                                         .what = ExternalToolsParameters::FileInfo::Path},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'f' ) { // terminal - current filename
                if( prompt || number || list )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::CurrentItem{.location = location(),
                                                         .what = ExternalToolsParameters::FileInfo::Filename},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'n' ) { // terminal - current filename without extension
                if( prompt || number || list )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::CurrentItem{
                        .location = location(), .what = ExternalToolsParameters::FileInfo::FilenameWithoutExtension},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'e' ) { // terminal - current extension
                if( prompt || number || list )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::CurrentItem{.location = location(),
                                                         .what = ExternalToolsParameters::FileInfo::FileExtension},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'F' ) { // terminal - selected filenames
                if( prompt )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::SelectedItems{.location = location(),
                                                           .what = ExternalToolsParameters::FileInfo::Filename,
                                                           .max = number.value_or(0),
                                                           .as_parameters = !list},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'P' ) { // terminal - selected filepaths
                if( prompt )
                    return error(); // malformed string, aborting
                result.emplace_back(
                    ExternalToolsParameters::SelectedItems{.location = location(),
                                                           .what = ExternalToolsParameters::FileInfo::Path,
                                                           .max = number.value_or(0),
                                                           .as_parameters = !list},
                    true);
                reset_placeholder();
                continue;
            }
            if( c == 'T' ) { // terminal - limit maxium total amount of files
                if( prompt || minus || list || !number )
                    return error(); // malformed string, aborting
                result.emplace_back(SetMaximumFilesFlag{static_cast<unsigned>(number.value())}, false);
                reset_placeholder();
                continue;
            }
            if( c == ' ' && minus && !list && !number && !prompt ) { // terminal - source change
                left_right = !left_right;
                reset_placeholder();
                continue;
            }
            return error();
        }

        if( c == ' ' && !escaped ) {
            // remove space separators
            if( !result.empty() )
                result.back().second = false;
            continue;
        }

        // otherwise, open a new user defined argument
        user_defined.emplace(1, c);
    }

    if( placeholder )
        return error();

    if( user_defined )
        result.emplace_back(ExternalToolsParameters::UserDefined{std::move(*user_defined)}, false);

    if( !result.empty() )
        result.back().second = false;

    return result;
}

std::expected<ExternalToolsParameters, std::string> ExternalToolsParametersParser::Parse(std::string_view _source)
{
    ExternalToolsParameters result;

    auto params = Eat(_source);
    if( !params )
        return std::unexpected(params.error());

    for( auto [param, partial] : params.value() ) {
        if( auto val = std::get_if<ExternalToolsParameters::UserDefined>(&param) ) {
            result.InsertUserDefinedText(std::move(*val), partial);
        }
        if( auto val = std::get_if<ExternalToolsParameters::EnterValue>(&param) ) {
            result.InsertValueRequirement(std::move(*val), partial);
        }
        if( auto val = std::get_if<ExternalToolsParameters::CurrentItem>(&param) ) {
            result.InsertCurrentItem(*val, partial);
        }
        if( auto val = std::get_if<ExternalToolsParameters::SelectedItems>(&param) ) {
            result.InsertSelectedItem(*val, partial);
        }
        if( auto val = std::get_if<SetMaximumFilesFlag>(&param) ) {
            result.m_MaximumTotalFiles = val->maximum;
        }
    }

    return result;
}

static nc::config::Value SaveTool(const ExternalTool &_et)
{
    using namespace rapidjson;
    using nc::config::g_CrtAllocator;
    using nc::config::MakeStandaloneString;
    nc::config::Value v(kObjectType);

    v.AddMember(MakeStandaloneString(g_TitleKey), MakeStandaloneString(_et.m_Title), g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_PathKey), MakeStandaloneString(_et.m_ExecutablePath), g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_ParametersKey), MakeStandaloneString(_et.m_Parameters), g_CrtAllocator);
    v.AddMember(
        MakeStandaloneString(g_ShortcutKey), MakeStandaloneString(_et.m_Shorcut.ToPersString()), g_CrtAllocator);
    v.AddMember(
        MakeStandaloneString(g_StartupKey), nc::config::Value(static_cast<int>(_et.m_StartupMode)), g_CrtAllocator);
    v.AddMember(MakeStandaloneString(g_UUIDKey), MakeStandaloneString(_et.m_UUID.ToString()), g_CrtAllocator);

    // TODO: save m_GUIArgumentInterpretation
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

    if( _from.HasMember(g_UUIDKey) && _from[g_UUIDKey].IsString() &&
        nc::base::UUID::FromString(_from[g_UUIDKey].GetString()) )
        et.m_UUID = nc::base::UUID::FromString(_from[g_UUIDKey].GetString()).value();

    // TODO: load m_GUIArgumentInterpretation
    return et;
}

ExternalToolsStorage::ExternalToolsStorage(const char *_config_path,
                                           nc::config::Config &_config,
                                           WriteChanges _write_changes)
    : m_ConfigPath(_config_path), m_Config(_config), m_WriteChanges(_write_changes)
{
    LoadToolsFromConfig();

    m_ConfigObservations.emplace_back(m_Config.Observe(_config_path, [this] {
        LoadToolsFromConfig();
        FireObservers();
    }));
}

void ExternalToolsStorage::LoadToolsFromConfig()
{
    auto tools = m_Config.Get(m_ConfigPath);
    if( !tools.IsArray() )
        return;

    bool did_invent_any_uuids = false;

    {
        auto lock = std::lock_guard{m_ToolsLock};
        m_Tools.clear();

        ankerl::unordered_dense::set<base::UUID> uuids;
        for( auto i = tools.Begin(), e = tools.End(); i != e; ++i ) {
            if( std::optional<ExternalTool> et = LoadTool(*i) ) {
                if( et->m_UUID == nc::base::UUID{} ) {
                    et->m_UUID = nc::base::UUID::Generate(); // Provide any "old" tool with a new uuid
                    did_invent_any_uuids = true;
                }

                // Ensure that all uuids are unique
                if( uuids.contains(et->m_UUID) ) {
                    et->m_UUID = base::UUID::Generate();
                    did_invent_any_uuids = true;
                }
                uuids.emplace(et->m_UUID);

                m_Tools.emplace_back(std::make_shared<ExternalTool>(std::move(*et)));
            }
        }
    }

    if( did_invent_any_uuids ) {
        CommitChanges();
    }
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

std::shared_ptr<const ExternalTool> ExternalToolsStorage::GetTool(const base::UUID &_uuid) const
{
    auto guard = std::lock_guard{m_ToolsLock};

    auto it = std::ranges::find_if(m_Tools, [&](auto &_tool) { return _tool->m_UUID == _uuid; });
    return it == m_Tools.end() ? nullptr : *it;
}

std::vector<std::shared_ptr<const ExternalTool>> ExternalToolsStorage::GetAllTools() const
{
    auto guard = std::lock_guard{m_ToolsLock};
    return m_Tools;
}

ExternalToolsStorage::ObservationTicket ExternalToolsStorage::ObserveChanges(std::function<void()> _callback)
{
    return AddObserver(std::move(_callback));
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
    if( m_WriteChanges == WriteChanges::Background ) {
        dispatch_to_background([=, this] { WriteToolsToConfig(); });
    }
    else {
        WriteToolsToConfig();
    }
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
        if( std::ranges::any_of(m_Tools, [&](auto &_existing) { return _existing->m_UUID == _tool.m_UUID; }) ) {
            throw std::invalid_argument("Duplicate UUID");
        }
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

std::string ExternalToolsStorage::NewTitle() const
{
    auto lock = std::lock_guard{m_ToolsLock};
    ankerl::unordered_dense::set<std::string> names;
    for( const auto &et : m_Tools ) {
        names.emplace(et->m_Title);
    }

    size_t idx = 0;
    const std::string prefix = NSLocalizedString(@"New Tool", "A placeholder title for a new external tool").UTF8String;
    while( true ) {
        const std::string name = idx == 0 ? prefix : fmt::format("{} {}", prefix, idx + 1);
        if( !names.contains(name) )
            return name;
        ++idx;
    }
}

ExternalToolExecution::ExternalToolExecution(const Context &_ctx, const ExternalTool &_et) : m_Ctx(_ctx), m_ET(_et)
{
    assert(m_Ctx.left_data);
    assert(m_Ctx.right_data);
    assert(m_Ctx.temp_storage);

    if( auto params = ExternalToolsParametersParser::Parse(m_ET.m_Parameters) )
        m_Params = std::move(params.value());
    else
        throw std::invalid_argument(params.error());

    for( int i = 0, e = static_cast<int>(m_Params.StepsAmount()); i != e; ++i )
        if( m_Params.StepNo(i).type == ExternalToolsParameters::ActionType::EnterValue )
            m_UserInputPrompts.emplace_back(m_Params.GetEnterValue(m_Params.StepNo(i).index).name);
}

void ExternalToolExecution::CommitUserInput(std::span<const std::string> _input)
{
    if( _input.size() != m_UserInputPrompts.size() )
        throw std::logic_error(
            fmt::format("ExternalToolExecution::CommitUserInput required {} inputs, but {} were provided",
                        m_UserInputPrompts.size(),
                        _input.size()));
    m_UserInput.assign(_input.begin(), _input.end());
}

bool ExternalToolExecution::RequiresUserInput() const noexcept
{
    return !m_UserInputPrompts.empty();
}

std::span<const std::string> ExternalToolExecution::UserInputPrompts() const noexcept
{
    return m_UserInputPrompts;
}

std::vector<std::string> ExternalToolExecution::BuildArguments() const
{
    std::vector<std::string> result;
    const size_t max_files =
        m_Params.GetMaximumTotalFiles() > 0 ? m_Params.GetMaximumTotalFiles() : std::numeric_limits<size_t>::max();
    size_t num_files = 0;

    bool append = false;
    auto commit = [&](std::string _arg) {
        if( append && !result.empty() )
            result.back() += _arg;
        else
            result.push_back(std::move(_arg));
    };
    auto panel_cursor_for_location =
        [&](ExternalToolsParameters::Location _location) -> std::pair<const panel::data::Model *, int> {
        switch( _location ) {
            case ExternalToolsParameters::Location::Left:
                return {m_Ctx.left_data, m_Ctx.left_cursor_pos};
            case ExternalToolsParameters::Location::Right:
                return {m_Ctx.right_data, m_Ctx.right_cursor_pos};
            case ExternalToolsParameters::Location::Source:
                return m_Ctx.focus == PanelFocus::left ? std::make_pair(m_Ctx.left_data, m_Ctx.left_cursor_pos)
                                                       : std::make_pair(m_Ctx.right_data, m_Ctx.right_cursor_pos);
            case ExternalToolsParameters::Location::Target:
                return m_Ctx.focus == PanelFocus::left ? std::make_pair(m_Ctx.right_data, m_Ctx.right_cursor_pos)
                                                       : std::make_pair(m_Ctx.left_data, m_Ctx.left_cursor_pos);
        }
    };
    auto info_from_item = [](const VFSListingItem &_item, ExternalToolsParameters::FileInfo _info) -> std::string {
        assert(_item);
        using FI = ExternalToolsParameters::FileInfo;
        switch( _info ) {
            case FI::Filename:
                return _item.Filename();
            case FI::Path:
                return _item.Path();
            case FI::FileExtension:
                return _item.ExtensionIfAny();
            case FI::FilenameWithoutExtension:
                return _item.FilenameWithoutExt();
            case FI::DirectoryPath:
                return EnsureNoTrailingSlash(_item.Directory());
        }
    };

    for( const auto step : m_Params.Steps() ) {
        if( step.type == ExternalToolsParameters::ActionType::UserDefined ) {
            const auto &v = m_Params.GetUserDefined(step.index);
            commit(v.text);
        }
        if( step.type == ExternalToolsParameters::ActionType::EnterValue ) {
            commit(m_UserInput.at(step.index));
        }
        if( step.type == ExternalToolsParameters::ActionType::CurrentItem && num_files < max_files ) {
            const auto v = m_Params.GetCurrentItem(step.index);
            const auto [panel, idx] = panel_cursor_for_location(v.location);
            if( const VFSListingItem item = panel->EntryAtSortPosition(idx) ) {
                commit(info_from_item(item, v.what));
                ++num_files;
            }
        }
        if( step.type == ExternalToolsParameters::ActionType::SelectedItems ) {
            append = false; // currently cannot concatentate multiple filenames into a single argument
            const auto &v = m_Params.GetSelectedItems(step.index);
            const auto [panel, idx] = panel_cursor_for_location(v.location);

            std::vector<VFSListingItem> items;
            for( auto ind : panel->SortedDirectoryEntries() ) {
                if( panel->VolatileDataAtRawPosition(ind).is_selected() )
                    if( auto e = panel->EntryAtRawPosition(ind) )
                        items.emplace_back(std::move(e));
                if( v.max != 0 && items.size() >= v.max )
                    break;
            }
            if( items.empty() ) {
                if( auto e = panel->EntryAtSortPosition(idx) )
                    if( e && !e.IsDotDot() )
                        items.emplace_back(std::move(e));
            }

            if( v.as_parameters ) {
                for( auto &item : items ) {
                    if( num_files++ >= max_files )
                        break;
                    commit(info_from_item(item, v.what));
                }
            }
            else {
                std::string list;
                for( auto &item : items ) {
                    if( num_files++ >= max_files )
                        break;
                    if( !list.empty() )
                        list += "\n";
                    list += info_from_item(item, v.what);
                }
                if( !list.empty() ) {
                    if( auto list_filename = m_Ctx.temp_storage->MakeFileFromMemory(list) )
                        commit(*list_filename);
                }
            }
        }
        append = step.partial;
    }
    return result;
}

bool ExternalToolExecution::IsBundle() const
{
    NSBundle *const b = [NSBundle bundleWithPath:[NSString stringWithUTF8StdString:m_ET.m_ExecutablePath]];
    return b != nil;
}

ExternalTool::StartupMode ExternalToolExecution::DeduceStartupMode() const
{
    switch( m_ET.m_StartupMode ) {
        case ExternalTool::StartupMode::RunDeatached:
            return ExternalTool::StartupMode::RunDeatached;
        case ExternalTool::StartupMode::RunInTerminal:
            return ExternalTool::StartupMode::RunInTerminal;
        case ExternalTool::StartupMode::Automatic:
            break;
    }
    return IsBundle() ? ExternalTool::StartupMode::RunDeatached : ExternalTool::StartupMode::RunInTerminal;
}

static bool IsRunnableExecutable(const std::string &_path)
{
    struct stat st;
    return stat(_path.c_str(), &st) == 0 && (st.st_mode & S_IFREG) != 0 && (st.st_mode & S_IRUSR) != 0 &&
           (st.st_mode & S_IXUSR) != 0;
}

static std::filesystem::path GetExecutablePathForBundle(const std::string &_path)
{
    if( NSBundle *const b = [NSBundle bundleWithPath:[NSString stringWithUTF8StdString:_path]] )
        if( NSURL *const u = b.executableURL )
            if( const char *fsr = u.fileSystemRepresentation )
                return fsr;
    return "";
}

std::filesystem::path ExternalToolExecution::ExecutablePath() const
{
    if( IsBundle() ) {
        if( IsRunnableExecutable(m_ET.m_ExecutablePath) ) {
            return m_ET.m_ExecutablePath;
        }
        if( auto p = GetExecutablePathForBundle(m_ET.m_ExecutablePath); !p.empty() ) {
            return p;
        }
    }
    return m_ET.m_ExecutablePath; // TODO: whereis?
}

std::expected<pid_t, std::string> ExternalToolExecution::StartDetached()
{
    // TODO: relative path from env?
    if( IsBundle() )
        return StartDetachedUI();
    else
        return StartDetachedFork();
}

std::expected<pid_t, std::string> ExternalToolExecution::StartDetachedFork() const
{
    auto args = BuildArguments();

    const int pid = nc::term::Task::RunDetachedProcess(m_ET.m_ExecutablePath, args);
    if( pid < 0 ) {
        return std::unexpected(VFSError::FormatErrorCode(VFSError::FromErrno()));
    }

    return pid;
}

std::expected<pid_t, std::string> ExternalToolExecution::StartDetachedUI()
{
    NSURL *const app_url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:m_ET.m_ExecutablePath]];

    const auto args = BuildArguments();

    NSMutableArray *const params_urls = [NSMutableArray new];
    NSMutableArray *const params_args = [NSMutableArray new];
    const bool allow_urls =
        m_ET.m_GUIArgumentInterpretation == ExternalTool::GUIArgumentInterpretation::PassExistingPathsAsURLs;
    for( auto &s : args ) {
        if( allow_urls && !s.empty() && s.front() == '/' && std::filesystem::exists(s) ) {
            // Add as a URL/document
            [params_urls addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8StdString:s]]];
        }
        else {
            // Add as a generic argument
            [params_args addObject:[NSString stringWithUTF8StdString:s]];
        }
    }

    NSWorkspaceOpenConfiguration *const config = [NSWorkspaceOpenConfiguration new];
    config.promptsUserIfNeeded = false;
    config.arguments = params_args;

    struct Ctx {
        std::mutex mut;
        std::condition_variable cv;
        bool done = false;
        NSRunningApplication *app = nil;
        NSError *error = nil;
    };

    auto ctx = std::make_shared<Ctx>();
    auto handler = ^(NSRunningApplication *_Nullable app, NSError *_Nullable error) {
      std::unique_lock lock{ctx->mut};
      ctx->app = app;
      ctx->error = error;
      ctx->done = true;
      lock.unlock();
      ctx->cv.notify_one();
    };

    if( params_urls.count ) {
        [NSWorkspace.sharedWorkspace openURLs:params_urls
                         withApplicationAtURL:app_url
                                configuration:config
                            completionHandler:handler];
    }
    else {
        [NSWorkspace.sharedWorkspace openApplicationAtURL:app_url configuration:config completionHandler:handler];
    }

    std::unique_lock lk(ctx->mut);
    const bool done = ctx->cv.wait_for(lk, std::chrono::seconds{10}, [&] { return ctx->done; });

    if( !done ) {
        return std::unexpected<std::string>(
            fmt::format("Failed to start '{}' due to a timeout", m_ET.m_ExecutablePath));
    }

    if( ctx->app ) {
        return ctx->app.processIdentifier;
    }

    if( ctx->error ) {
        return std::unexpected<std::string>(ctx->error.localizedDescription.UTF8String);
    }

    abort(); // internal logic error
}

} // namespace nc::panel
