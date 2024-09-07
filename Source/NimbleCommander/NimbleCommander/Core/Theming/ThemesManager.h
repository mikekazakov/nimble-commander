// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/Observable.h>
#include <Base/UnorderedUtil.h>
#include <Config/Config.h>

#include "Appearance.h"

#include <compare>
#include <vector>
#include <string>
#include <string_view>

namespace nc {

class Theme;

/**
 * This class is not thread-safe yet!
 */
class ThemesManager : base::ObservableBase
{
public:
    struct Notifications;
    struct AutoSwitchingSettings;

    // Creates a new manager which will load/store the themes data inside the provided '_config' in at the
    // '_themes_storage_path' location.
    // _config's lifespan must be longer than the theme manager's - it's referenced at internally.
    // '_current_theme_path' denotes the path to the string value with a name of currently selected theme.
    ThemesManager(config::Config &_config, std::string_view _current_theme_path, std::string_view _themes_storage_path);

    /**
     * Returns name of a currently selected user theme.
     */
    std::string SelectedThemeName() const;

    // Returns the currently active theme.
    const Theme &SelectedTheme() const;

    /**
     * Changes currently selected name, updates config, updates current theme object and
     * fires notifications.
     */
    bool SelectTheme(const std::string &_theme_name);

    /**
     * Returns a list of theme names currently installed for this user.
     */
    std::vector<std::string> ThemeNames() const;

    /**
     * Check if this theme is one of default themes.
     */
    bool HasDefaultSettings(const std::string &_theme_name) const noexcept;

    /**
     * Tells if this theme can be removed. Themes that are bundled with the app can't.
     */
    bool CanBeRemoved(const std::string &_theme_name) const noexcept;

    /**
     * Effectively returns ThemeData( SelectedThemeName() ).
     */
    std::shared_ptr<const nc::config::Value> SelectedThemeData() const;

    /**
     * Returns current json document for specified theme.
     * May return shared ptr to kNullType.
     */
    std::shared_ptr<const nc::config::Value> ThemeData(const std::string &_theme_name) const;

    /**
     * Tries to find a default value for this theme.
     * If there's no - returns a value for Modern theme.
     */
    std::shared_ptr<const nc::config::Value> BackupThemeData(const std::string &_theme_name) const;

    /**
     * Changes a theme value, if theme can't be found or value is the same - returns false.
     */
    bool SetThemeValue(const std::string &_theme_name, const std::string &_key, const nc::config::Value &_value);

    /**
     * Performs per-element document merge, replacing values in theme named _theme_name with
     * values from _data. Any unchanged or absent in _data values are untouched.
     * Theme called _theme_name must exist upon this request.
     */
    bool ImportThemeData(const std::string &_theme_name, const nc::config::Value &_data);

    /**
     * Insert new theme. There must be no _theme_name prior this call.
     */
    bool AddTheme(const std::string &_theme_name, const nc::config::Value &_data);

    /**
     * Check for existing themes and tries to find a suitable name for suggested name,
     * may add a postfix number.
     */
    std::string SuitableNameForNewTheme(const std::string &_current_theme_name) const;

    /**
     * Reverts state of specified theme to default value.
     * If there's no default value for this theme or there were no changes - does
     * nothing and returns false.
     */
    bool DiscardThemeChanges(const std::string &_theme_name);

    /**
     * Deletes specified theme. Only non-default themes can be removed.
     * If it was a selected theme - changes it too.
     */
    bool RemoveTheme(const std::string &_theme_name);

    // Checks if the theme can be renamed. Only custom themes can be renamed.
    bool CanBeRenamed(const std::string &_theme_name) const;

    /**
     * Renames specified theme to new name. If it is one of default ones - it can't be renamed.
     * If some theme named _to_name already exist - returns false.
     * If _theme_name is a selected theme - updates it too.
     */
    bool RenameTheme(const std::string &_theme_name, const std::string &_to_name);

    // Returns true if themes will be automatically switched once system's theme is changed.
    bool DoesAutomaticSwitching() const;

    // Sets the theme names to be automatically switched to once system's theme is changed if enabled.
    // Automatically propagates the settings into the underlying config.
    void SetAutomaticSwitching(const AutoSwitchingSettings &_as);

    // Returns current setting of automatic themes switching
    AutoSwitchingSettings AutomaticSwitching() const;

    // Notifies the theme manager that the system appearance has changed.
    // The automatic theme switching is enabled this will select a theme according to those settings.
    void NotifyAboutSystemAppearanceChange(ThemeAppearance _appearance);

    using ObservationTicket = ObservableBase::ObservationTicket;

    // Adds an observation for the given events
    ObservationTicket ObserveChanges(uint64_t _notification_mask, std::function<void()> _callback);

private:
    // Not copy-constructable
    ThemesManager(const ThemesManager &) = delete;

    // Note copy-assignable
    ThemesManager &operator=(const ThemesManager &) = delete;

    using ThemesDataT = ankerl::unordered_dense::map<std::string,
                                                     std::shared_ptr<const nc::config::Document>,
                                                     UnorderedStringHashEqual,
                                                     UnorderedStringHashEqual>;

    void LoadThemes();
    void LoadDefaultThemes();
    void LoadSwitchingSettings();
    void WriteThemes() const;
    void WriteSwitchingSettings();
    void UpdateCurrentTheme();

    config::Config &m_Config;
    std::string m_CurrentThemePath;
    std::string m_ThemesStoragePath;
    std::string m_ThemesArrayPath;
    std::string m_SelectedThemeName;
    bool m_AutomaticSwitchingEnabled = false;
    std::string m_AutoLightThemeName;
    std::string m_AutoDarkThemeName;
    ThemesDataT m_Themes;
    std::vector<std::string> m_OrderedThemeNames;
    ThemesDataT m_DefaultThemes;
    std::vector<std::string> m_OrderedDefaultThemeNames;
    ObservationTicket m_AppearanceObservation;
};

struct ThemesManager::Notifications {
    enum : uint64_t {
        // Current theme has changed completely (i.e. another one was selected)
        Name = 1 << 0,

        // Appearance has changed
        Appearance = 1 << 1,

        // File panels - general theming has changed
        FilePanelsGeneral = 1 << 2,

        // File panels - tabs theming has changed
        FilePanelsTabs = 1 << 3,

        // File panels - header theming has changed
        FilePanelsHeader = 1 << 4,

        // File panels - footer theming has changed
        FilePanelsFooter = 1 << 5,

        // File panels - brief presentation mode's theming has changed
        FilePanelsBrief = 1 << 6,

        // File panels - list presentation mode's theming has changed
        FilePanelsList = 1 << 7,

        // Viewer-related theming has changed
        Viewer = 1 << 8,

        // Terminal-related theming has changed
        Terminal = 1 << 9
    };
};

struct ThemesManager::AutoSwitchingSettings {
    // whether this automatic switching should happen
    bool enabled;

    // the name of a theme to be selected when system changes appearance to Light
    std::string light;

    // the name of a theme to be selected when system changes appearance to Dark
    std::string dark;

    std::strong_ordering operator<=>(const AutoSwitchingSettings &) const noexcept = default;
};

} // namespace nc
