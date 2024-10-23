// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ThemesManager.h"
#include "Theme.h"
#include <Base/dispatch_cpp.h>
#include <Config/RapidJSON.h>
#include <algorithm>
#include <ankerl/unordered_dense.h>
#include <charconv>
#include <fmt/core.h>
#include <frozen/string.h>
#include <frozen/unordered_map.h>
#include <ranges>

namespace nc {

static const auto g_NameKey = "themeName";

[[clang::no_destroy]] static std::shared_ptr<const Theme> g_CurrentTheme;

template <size_t size, typename T, size_t... indexes>
static constexpr auto make_array_n_impl(T &&value, std::index_sequence<indexes...> /*unused*/)
{
    return std::array<std::decay_t<T>, size>{(static_cast<void>(indexes), value)..., std::forward<T>(value)};
}

template <size_t size, typename T>
static constexpr auto make_array_n(T &&value)
{
    return make_array_n_impl<size>(std::forward<T>(value), std::make_index_sequence<size - 1>{});
}

using TMN = ThemesManager::Notifications;
static constexpr std::pair<const char *, uint64_t> g_EntryToNotificationMappingTable[] = {
    {"themeAppearance", TMN::Appearance},
    {"filePanelsColoringRules_v1", TMN::FilePanelsGeneral},
    {"filePanelsGeneralDropBorderColor", TMN::FilePanelsGeneral},
    {"filePanelsGeneralOverlayColor", TMN::FilePanelsGeneral},
    {"filePanelsGeneralSplitterColor", TMN::FilePanelsGeneral},
    {"filePanelsGeneralTopSeparatorColor", TMN::FilePanelsGeneral},
    {"filePanelsTabsFont", TMN::FilePanelsTabs},
    {"filePanelsTabsTextColor", TMN::FilePanelsTabs},
    {"filePanelsTabsSelectedKeyWndActiveBackgroundColor", TMN::FilePanelsTabs},
    {"filePanelsTabsSelectedKeyWndInactiveBackgroundColor", TMN::FilePanelsTabs},
    {"filePanelsTabsSelectedNotKeyWndBackgroundColor", TMN::FilePanelsTabs},
    {"filePanelsTabsRegularKeyWndHoverBackgroundColor", TMN::FilePanelsTabs},
    {"filePanelsTabsRegularKeyWndRegularBackgroundColor", TMN::FilePanelsTabs},
    {"filePanelsTabsRegularNotKeyWndBackgroundColor", TMN::FilePanelsTabs},
    {"filePanelsTabsSeparatorColor", TMN::FilePanelsTabs},
    {"filePanelsTabsPictogramColor", TMN::FilePanelsTabs},
    {"filePanelsHeaderFont", TMN::FilePanelsHeader},
    {"filePanelsHeaderTextColor", TMN::FilePanelsHeader},
    {"filePanelsHeaderActiveTextColor", TMN::FilePanelsHeader},
    {"filePanelsHeaderActiveBackgroundColor", TMN::FilePanelsHeader},
    {"filePanelsHeaderInactiveBackgroundColor", TMN::FilePanelsHeader},
    {"filePanelsHeaderSeparatorColor", TMN::FilePanelsHeader},
    {"filePanelsFooterFont", TMN::FilePanelsFooter},
    {"filePanelsFooterTextColor", TMN::FilePanelsFooter},
    {"filePanelsFooterActiveTextColor", TMN::FilePanelsFooter},
    {"filePanelsFooterSeparatorsColor", TMN::FilePanelsFooter},
    {"filePanelsFooterActiveBackgroundColor", TMN::FilePanelsFooter},
    {"filePanelsFooterInactiveBackgroundColor", TMN::FilePanelsFooter},
    {"filePanelsListFont", TMN::FilePanelsList},
    {"filePanelsListGridColor", TMN::FilePanelsList},
    {"filePanelsListHeaderFont", TMN::FilePanelsList},
    {"filePanelsListHeaderBackgroundColor", TMN::FilePanelsList},
    {"filePanelsListHeaderTextColor", TMN::FilePanelsList},
    {"filePanelsListHeaderSeparatorColor", TMN::FilePanelsList},
    {"filePanelsListFocusedActiveRowBackgroundColor", TMN::FilePanelsList},
    {"filePanelsListFocusedInactiveRowBackgroundColor", TMN::FilePanelsList},
    {"filePanelsListRegularEvenRowBackgroundColor", TMN::FilePanelsList},
    {"filePanelsListRegularOddRowBackgroundColor", TMN::FilePanelsList},
    {"filePanelsListSelectedItemBackgroundColor", TMN::FilePanelsList},
    {"filePanelsBriefFont", TMN::FilePanelsBrief},
    {"filePanelsBriefGridColor", TMN::FilePanelsBrief},
    {"filePanelsBriefRegularEvenRowBackgroundColor", TMN::FilePanelsBrief},
    {"filePanelsBriefRegularOddRowBackgroundColor", TMN::FilePanelsBrief},
    {"filePanelsBriefFocusedActiveItemBackgroundColor", TMN::FilePanelsBrief},
    {"filePanelsBriefFocusedInactiveItemBackgroundColor", TMN::FilePanelsBrief},
    {"filePanelsBriefSelectedItemBackgroundColor", TMN::FilePanelsBrief},
    {"terminalFont", TMN::Terminal},
    {"terminalOverlayColor", TMN::Terminal},
    {"terminalForegroundColor", TMN::Terminal},
    {"terminalBoldForegroundColor", TMN::Terminal},
    {"terminalBackgroundColor", TMN::Terminal},
    {"terminalSelectionColor", TMN::Terminal},
    {"terminalCursorColor", TMN::Terminal},
    {"terminalAnsiColor0", TMN::Terminal},
    {"terminalAnsiColor1", TMN::Terminal},
    {"terminalAnsiColor2", TMN::Terminal},
    {"terminalAnsiColor3", TMN::Terminal},
    {"terminalAnsiColor4", TMN::Terminal},
    {"terminalAnsiColor5", TMN::Terminal},
    {"terminalAnsiColor6", TMN::Terminal},
    {"terminalAnsiColor7", TMN::Terminal},
    {"terminalAnsiColor8", TMN::Terminal},
    {"terminalAnsiColor9", TMN::Terminal},
    {"terminalAnsiColorA", TMN::Terminal},
    {"terminalAnsiColorB", TMN::Terminal},
    {"terminalAnsiColorC", TMN::Terminal},
    {"terminalAnsiColorD", TMN::Terminal},
    {"terminalAnsiColorE", TMN::Terminal},
    {"terminalAnsiColorF", TMN::Terminal},
    {"viewerFont", TMN::Viewer},
    {"viewerOverlayColor", TMN::Viewer},
    {"viewerTextColor", TMN::Viewer},
    {"viewerTextSyntaxCommentColor", TMN::Viewer},
    {"viewerTextSyntaxPreprocessorColor", TMN::Viewer},
    {"viewerTextSyntaxKeywordColor", TMN::Viewer},
    {"viewerTextSyntaxOperatorColor", TMN::Viewer},
    {"viewerTextSyntaxIdentifierColor", TMN::Viewer},
    {"viewerTextSyntaxNumberColor", TMN::Viewer},
    {"viewerTextSyntaxStringColor", TMN::Viewer},
    {"viewerSelectionColor", TMN::Viewer},
    {"viewerBackgroundColor", TMN::Viewer},
};

static constinit const auto g_EntryToNotificationMapping = [] {
    auto items = make_array_n<std::size(g_EntryToNotificationMappingTable)>(
        std::pair<frozen::string, uint64_t>(frozen::string(""), 0));
    for( size_t i = 0; i < std::size(g_EntryToNotificationMappingTable); ++i )
        items[i] = std::pair<frozen::string, uint64_t>(g_EntryToNotificationMappingTable[i].first,
                                                       g_EntryToNotificationMappingTable[i].second);
    return frozen::make_unordered_map(items);
}();

static std::string MigrateThemeName(const std::string &_name);
static std::optional<std::string> ExtractThemeNameAppearance(const nc::config::Value &_doc);

ThemesManager::ThemesManager(config::Config &_config,
                             std::string_view _current_theme_path,
                             std::string_view _themes_storage_path)
    : m_Config(_config), m_CurrentThemePath(_current_theme_path), m_ThemesStoragePath(_themes_storage_path),
      m_ThemesArrayPath(std::string(_themes_storage_path) + ".themes_v1")
{
    LoadDefaultThemes();
    LoadThemes();
    m_SelectedThemeName = m_Config.Has(m_CurrentThemePath) ? m_Config.GetString(m_CurrentThemePath) : "Light";
    m_SelectedThemeName = MigrateThemeName(m_SelectedThemeName);
    UpdateCurrentTheme();
    LoadSwitchingSettings();
}

void ThemesManager::LoadThemes()
{
    auto themes = m_Config.Get(m_ThemesArrayPath);
    if( !themes.IsArray() )
        return;

    m_OrderedThemeNames = m_OrderedDefaultThemeNames;

    // Load themes from the current state
    for( auto i = themes.Begin(), e = themes.End(); i != e; ++i ) {
        if( !i->IsObject() )
            continue;
        const std::optional<std::string> name = ExtractThemeNameAppearance(*i);
        if( !name )
            continue;
        if( m_Themes.contains(*name) )
            continue; // broken config - duplicate theme declaration, prohibit such stuff

        nc::config::Document doc;
        doc.CopyFrom(*i, nc::config::g_CrtAllocator);

        m_Themes.emplace(*name, std::make_shared<nc::config::Document>(std::move(doc)));

        if( std::ranges::find(m_OrderedThemeNames, *name) == m_OrderedThemeNames.end() )
            m_OrderedThemeNames.emplace_back(*name);
    }

    // Load any new themes that were added into the defaults
    for( auto &name : m_OrderedDefaultThemeNames ) {
        if( !m_Themes.contains(name) ) {
            m_Themes.emplace(name, m_DefaultThemes.at(name));
        }
    }
}

void ThemesManager::LoadDefaultThemes()
{
    auto themes = m_Config.GetDefault(m_ThemesArrayPath);
    if( !themes.IsArray() )
        return;

    for( auto i = themes.Begin(), e = themes.End(); i != e; ++i ) {
        if( !i->IsObject() )
            continue;
        const std::optional<std::string> name = ExtractThemeNameAppearance(*i);
        if( !name )
            continue;

        nc::config::Document doc;
        doc.CopyFrom(*i, nc::config::g_CrtAllocator);

        m_DefaultThemes.emplace(*name, std::make_shared<nc::config::Document>(std::move(doc)));
        m_OrderedDefaultThemeNames.emplace_back(*name);
    }
}

std::string ThemesManager::SelectedThemeName() const
{
    return m_SelectedThemeName;
}

std::shared_ptr<const nc::config::Value> ThemesManager::SelectedThemeData() const
{
    auto i = ThemeData(m_SelectedThemeName);
    if( i->GetType() == rapidjson::kObjectType )
        return i;

    // at this moment there's some inconsistency in config, lets use a failsafe Light theme.
    return BackupThemeData("Light");
}

std::shared_ptr<const nc::config::Value> ThemesManager::ThemeData(const std::string &_theme_name) const
{
    auto it = m_Themes.find(_theme_name);
    if( it != m_Themes.end() )
        return it->second;

    [[clang::no_destroy]] static const auto dummy = std::make_shared<nc::config::Value>(rapidjson::kNullType);
    return dummy;
}

std::shared_ptr<const nc::config::Value> ThemesManager::BackupThemeData(const std::string &_theme_name) const
{
    auto i = m_DefaultThemes.find(_theme_name);
    if( i != m_DefaultThemes.end() )
        return i->second;

    i = m_DefaultThemes.find("Light");
    if( i != m_DefaultThemes.end() )
        return i->second;

    assert("default config is corrupted, there's no Light theme" == nullptr);
    abort();
}

static uint64_t NotificationMaskForKey(std::string_view _key) noexcept
{
    const auto it = g_EntryToNotificationMapping.find(_key);
    return it != g_EntryToNotificationMapping.end() ? it->second : 0;
}

bool ThemesManager::SetThemeValue(const std::string &_theme_name,
                                  const std::string &_key,
                                  const nc::config::Value &_value)
{
    auto it = m_Themes.find(_theme_name);
    if( it == m_Themes.end() )
        return false;

    auto &d = *it->second;

    if( d.HasMember(_key.c_str()) )
        if( d[_key.c_str()] == _value )
            return true;

    nc::config::Document new_doc;
    new_doc.CopyFrom(d, nc::config::g_CrtAllocator);
    new_doc.RemoveMember(_key.c_str());
    new_doc.AddMember(nc::config::MakeStandaloneString(_key),
                      nc::config::Value(_value, nc::config::g_CrtAllocator),
                      nc::config::g_CrtAllocator);

    it->second = std::make_shared<nc::config::Document>(std::move(new_doc));

    // if this is a selected theme
    if( _theme_name == m_SelectedThemeName ) {
        UpdateCurrentTheme();
        FireObservers(NotificationMaskForKey(_key));
    }

    // TODO: move to background thread, delay execution
    WriteThemes();
    return true;
}

void ThemesManager::UpdateCurrentTheme()
{
    using namespace std::literals;

    // comprose new theme object
    auto theme_data = SelectedThemeData();
    assert(theme_data);
    auto new_theme = std::make_shared<Theme>(*theme_data, *BackupThemeData(m_SelectedThemeName));

    // release current theme some time after - dispatch release with 10s delay
    auto old_theme = g_CurrentTheme;
    dispatch_to_main_queue_after(5s, [old_theme]() mutable { old_theme = nullptr; });

    // set new theme object
    g_CurrentTheme = new_theme;
}

const Theme &CurrentTheme() noexcept
{
    assert(g_CurrentTheme != nullptr);
    return *g_CurrentTheme;
}

// NOLINTNEXTLINE(readability-convert-member-functions-to-static)
const Theme &ThemesManager::SelectedTheme() const
{
    assert(g_CurrentTheme != nullptr);
    return *g_CurrentTheme;
}

std::vector<std::string> ThemesManager::ThemeNames() const
{
    return m_OrderedThemeNames;
}

// todo: move to background, need to be thread-safe
void ThemesManager::WriteThemes() const
{
    nc::config::Value json_themes{rapidjson::kArrayType};
    for( auto &tn : m_OrderedThemeNames ) {
        auto i = m_Themes.find(tn);
        assert(i != end(m_Themes));

        nc::config::Value theme{rapidjson::kObjectType};
        theme.CopyFrom(*i->second, nc::config::g_CrtAllocator);
        json_themes.PushBack(std::move(theme), nc::config::g_CrtAllocator);
    }
    m_Config.Set(m_ThemesArrayPath, json_themes);
}

bool ThemesManager::SelectTheme(const std::string &_theme_name)
{
    if( m_SelectedThemeName == _theme_name )
        return true;

    if( !m_Themes.count(_theme_name) )
        return false;

    m_SelectedThemeName = _theme_name;
    m_Config.Set(m_CurrentThemePath, m_SelectedThemeName);

    UpdateCurrentTheme();
    // figure out what has changed
    // do some magic stuff to notify everybody about changes

    FireObservers(); // temporary overkill solution - just rebuild everything

    return true;
}

ThemesManager::ObservationTicket ThemesManager::ObserveChanges(uint64_t _notification_mask,
                                                               std::function<void()> _callback)
{
    return AddObserver(std::move(_callback), _notification_mask);
}

bool ThemesManager::HasDefaultSettings(const std::string &_theme_name) const noexcept
{
    return m_DefaultThemes.contains(_theme_name);
}

bool ThemesManager::DiscardThemeChanges(const std::string &_theme_name)
{
    auto ci = m_Themes.find(_theme_name);
    if( ci == m_Themes.end() )
        return false;

    auto di = m_DefaultThemes.find(_theme_name);
    if( di == m_DefaultThemes.end() )
        return false; // there's no "default" counterpart

    if( *ci->second == *di->second )
        return false; // no changes

    ci->second = di->second;

    // if this is a selected theme
    if( _theme_name == m_SelectedThemeName ) {
        UpdateCurrentTheme();
        FireObservers(); // temporary overkill solution - just rebuild everything
    }

    // TODO: move to background thread, delay execution
    WriteThemes();
    return true;
}

bool ThemesManager::ImportThemeData(const std::string &_theme_name, const nc::config::Value &_data)
{
    if( _data.GetType() != rapidjson::kObjectType )
        return false;

    auto it = m_Themes.find(_theme_name);
    if( it == end(m_Themes) )
        return false;

    auto &old_doc = *it->second;

    nc::config::Document new_doc;
    new_doc.CopyFrom(old_doc, nc::config::g_CrtAllocator);

    bool any = false;
    uint64_t changes_mask = 0;
    for( auto i = _data.MemberBegin(), e = _data.MemberEnd(); i != e; ++i ) {
        if( i->name == g_NameKey )
            continue;

        if( new_doc.HasMember(i->name) )
            if( new_doc[i->name] == i->value )
                continue;

        new_doc.RemoveMember(i->name);
        new_doc.AddMember(nc::config::MakeStandaloneString(i->name.GetString()),
                          nc::config::Value(i->value, nc::config::g_CrtAllocator),
                          nc::config::g_CrtAllocator);
        changes_mask |= NotificationMaskForKey(i->name.GetString());
        any = true;
    }

    if( !any )
        return false;

    // put new data into our working dictionary
    it->second = std::make_shared<nc::config::Document>(std::move(new_doc));

    // if this is a selected theme
    if( _theme_name == m_SelectedThemeName ) {
        UpdateCurrentTheme();
        FireObservers(changes_mask);
    }

    // TODO: move to background thread, delay execution
    WriteThemes();

    return true;
}

bool ThemesManager::AddTheme(const std::string &_theme_name, const nc::config::Value &_data)
{
    if( _theme_name.empty() || m_Themes.count(_theme_name) )
        return false;

    nc::config::Document doc;
    doc.CopyFrom(_data, nc::config::g_CrtAllocator);

    doc.RemoveMember(g_NameKey);
    doc.AddMember(nc::config::MakeStandaloneString(g_NameKey),
                  nc::config::MakeStandaloneString(_theme_name),
                  nc::config::g_CrtAllocator);

    m_Themes.emplace(_theme_name, std::make_shared<nc::config::Document>(std::move(doc)));
    m_OrderedThemeNames.emplace_back(_theme_name);

    // TODO: move to background thread, delay execution
    WriteThemes();

    return true;
}

std::string ThemesManager::SuitableNameForNewTheme(const std::string &_current_theme_name) const
{
    if( _current_theme_name.empty() )
        return {}; // empty names are not allowed

    const auto themes = ThemeNames();
    const ankerl::unordered_dense::set<std::string> names(themes.begin(), themes.end());

    if( !names.contains(_current_theme_name) ) {
        // no collision, accept as-is
        return _current_theme_name;
    }

    // check if _current_theme_name already contains a trailing number - continue in that case, otherwise start with 2
    const std::string &cn = _current_theme_name;
    const auto sp_idx = cn.rfind(' ');
    int current_idx = 2;
    if( sp_idx != std::string::npos &&
        std::from_chars(cn.data() + sp_idx + 1, cn.data() + cn.length(), current_idx).ec == std::errc{} ) {
        for( ; current_idx < 99; ++current_idx ) {
            auto name = fmt::format("{} {}", std::string_view(cn.data(), sp_idx), current_idx);
            if( !names.contains(name) )
                return name;
        }
    }
    else {
        for( ; current_idx < 99; ++current_idx ) {
            auto name = fmt::format("{} {}", cn, current_idx);
            if( !names.contains(name) )
                return name;
        }
    }

    return "";
}

bool ThemesManager::CanBeRemoved(const std::string &_theme_name) const noexcept
{
    return m_Themes.contains(_theme_name) && !HasDefaultSettings(_theme_name);
}

bool ThemesManager::RemoveTheme(const std::string &_theme_name)
{
    if( !CanBeRemoved(_theme_name) )
        return false;

    m_Themes.erase(_theme_name);

    std::erase(m_OrderedThemeNames, _theme_name);

    // TODO: move to background thread, delay execution
    WriteThemes();

    if( m_SelectedThemeName == _theme_name )
        SelectTheme(m_OrderedDefaultThemeNames.at(0));

    if( m_AutoLightThemeName == _theme_name ) {
        m_AutoLightThemeName = "Light"; // Assuming we always have the Light theme
        WriteSwitchingSettings();
    }
    if( m_AutoDarkThemeName == _theme_name ) {
        m_AutoDarkThemeName = "Dark"; // Assuming we always have the Dark theme
        WriteSwitchingSettings();
    }
    return true;
}

bool ThemesManager::CanBeRenamed(const std::string &_theme_name) const
{
    return m_Themes.contains(_theme_name) && !HasDefaultSettings(_theme_name);
}

bool ThemesManager::RenameTheme(const std::string &_theme_name, const std::string &_to_name)
{
    if( _theme_name == _to_name )
        return false;

    if( !CanBeRenamed(_theme_name) )
        return false;

    if( m_Themes.count(_to_name) )
        return false;

    auto old_doc = ThemeData(_theme_name);
    if( !old_doc || old_doc->GetType() != rapidjson::kObjectType )
        return false;

    nc::config::Document doc;
    doc.CopyFrom(*old_doc, nc::config::g_CrtAllocator);

    doc.RemoveMember(g_NameKey);
    doc.AddMember(nc::config::MakeStandaloneString(g_NameKey),
                  nc::config::MakeStandaloneString(_to_name),
                  nc::config::g_CrtAllocator);

    m_Themes.erase(_theme_name);
    m_Themes.emplace(_to_name, std::make_shared<nc::config::Document>(std::move(doc)));
    std::ranges::replace(m_OrderedThemeNames, _theme_name, _to_name);

    // TODO: move to background thread, delay execution
    WriteThemes();

    if( m_SelectedThemeName == _theme_name )
        SelectTheme(_to_name);

    return true;
}

bool ThemesManager::DoesAutomaticSwitching() const
{
    return m_AutomaticSwitchingEnabled;
}

void ThemesManager::SetAutomaticSwitching(const AutoSwitchingSettings &_as)
{
    m_AutomaticSwitchingEnabled = _as.enabled;
    m_AutoLightThemeName = _as.light;
    m_AutoDarkThemeName = _as.dark;
    WriteSwitchingSettings();
}

ThemesManager::AutoSwitchingSettings ThemesManager::AutomaticSwitching() const
{
    return {.enabled = m_AutomaticSwitchingEnabled, .light = m_AutoLightThemeName, .dark = m_AutoDarkThemeName};
}

void ThemesManager::NotifyAboutSystemAppearanceChange(ThemeAppearance _appearance)
{
    if( !m_AutomaticSwitchingEnabled )
        return; // nothing to do, ignore the notification

    if( _appearance == ThemeAppearance::Light ) {
        SelectTheme(m_AutoLightThemeName); // bogus / empty names are ok here
    }
    if( _appearance == ThemeAppearance::Dark ) {
        SelectTheme(m_AutoDarkThemeName); // bogus / empty names are ok here
    }
}

void ThemesManager::LoadSwitchingSettings()
{
    // off if something goes wrong
    const bool enabled = m_Config.GetBool(m_ThemesStoragePath + ".automaticSwitching.enabled");
    // empty if something goes wrong
    const std::string light = m_Config.GetString(m_ThemesStoragePath + ".automaticSwitching.light");
    // empty if something goes wrong
    const std::string dark = m_Config.GetString(m_ThemesStoragePath + ".automaticSwitching.dark");

    m_AutomaticSwitchingEnabled = enabled;
    m_AutoLightThemeName = light;
    m_AutoDarkThemeName = dark;
}

void ThemesManager::WriteSwitchingSettings()
{
    m_Config.Set(m_ThemesStoragePath + ".automaticSwitching.enabled", m_AutomaticSwitchingEnabled);
    m_Config.Set(m_ThemesStoragePath + ".automaticSwitching.light", m_AutoLightThemeName);
    m_Config.Set(m_ThemesStoragePath + ".automaticSwitching.dark", m_AutoDarkThemeName);
}

static std::string MigrateThemeName(const std::string &_name)
{
    // specifially manually 'migrate' the old theme name to the new one
    return _name == "Modern" ? "Light" : _name;
}

static std::optional<std::string> ExtractThemeNameAppearance(const nc::config::Value &_doc)
{
    auto it = _doc.FindMember(g_NameKey);
    if( it == _doc.MemberEnd() )
        return {};
    if( !it->value.IsString() )
        return {};

    return MigrateThemeName(it->value.GetString());
}

} // namespace nc
