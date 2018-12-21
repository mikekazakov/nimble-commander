// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/Observable.h>
#include <Config/RapidJSON_fwd.h>

#include <unordered_map>
#include <vector>
#include <string>

class Theme;

/**
 * This class is not thread-safe yet!
 */
class ThemesManager : ObservableBase
{
public:
    struct Notifications {
        enum : uint64_t{
            Appearance          = 0x00000001,
            FilePanelsGeneral   = 0x00000002,
            FilePanelsTabs      = 0x00000004,
            FilePanelsHeader    = 0x00000008,
            FilePanelsFooter    = 0x00000010,
            FilePanelsBrief     = 0x00000020,
            FilePanelsList      = 0x00000040,
            Viewer              = 0x00000080,
            Terminal            = 0x00000100
        };
    };

    ThemesManager( const char *_current_theme_path, const char *_themes_storage_path );
    
    /**
     * Returns name of a currently selected user theme.
     */
    std::string SelectedThemeName() const;
    
    const Theme &SelectedTheme() const;
    
    /**
     * Changes currently selected name, updates config, updates current theme object and
     * fires notifications.
     */
    bool SelectTheme( const std::string &_theme_name );
    
    /**
     * Returns a list of theme names currently installed for this user.
     */
    std::vector<std::string> ThemeNames() const;
    
    /**
     * Check if this theme is one of default themes.
     */
    bool HasDefaultSettings( const std::string &_theme_name ) const;
    
    /**
     * Tells if this theme can be removed. Themes that are bundled this app can't.
     */
    bool CanBeRemoved( const std::string &_theme_name ) const;
    
    /**
     * Effectively returns ThemeData( SelectedThemeName() ).
     */
    std::shared_ptr<const nc::config::Value> SelectedThemeData() const;
    
    /**
     * Returns current json document for specified theme.
     * May return shared ptr to kNullType.
     */
    std::shared_ptr<const nc::config::Value> ThemeData( const std::string &_theme_name ) const;
    
    /**
     * Tries to find a default value for this theme.
     * If there's no - returns a value for Modern theme.
     */
    std::shared_ptr<const nc::config::Value> BackupThemeData( const std::string &_theme_name ) const;
    
    /**
     * Changes a theme value, if theme can't be found or value is the same - returns false.
     */
    bool SetThemeValue(const std::string &_theme_name,
                       const std::string &_key,
                       const nc::config::Value &_value);
    
    /**
     * Performs per-element document merge, replacing values in theme named _theme_name with
     * values from _data. Any unchanged or absent in _data values are untouched.
     * Theme called _theme_name must exist upon this request.
     */
    bool ImportThemeData(const std::string &_theme_name,
                         const nc::config::Value &_data);
    
    /**
     * Insert new theme. There must be no _theme_name prior this call.
     */
    bool AddTheme(const std::string &_theme_name,
                  const nc::config::Value &_data);
    
    /**
     * Check for existing themes and tries to find a suitable name for suggested name, 
     * may add a postfix number.
     */
    std::string SuitableNameForNewTheme( const std::string &_current_theme_name ) const;
    
    /**
     * Reverts state of specified theme to default value.
     * If there's no default value for this theme or there were no changes - does
     * nothing and returns false.
     */
    bool DiscardThemeChanges( const std::string &_theme_name );
    
    /**
     * Deletes specified theme. Only non-default themes can be removed.
     * If it was a selected theme - changes it too.
     */
    bool RemoveTheme( const std::string &_theme_name );
    
    bool CanBeRenamed( const std::string &_theme_name ) const;
    
    /**
     * Renames specified theme to new name. If it is one of default ones - it can't be renamed.
     * If some theme named _to_name already exist - returns false.
     * If _theme_name is a selected theme - updates it too.
     */
    bool RenameTheme( const std::string &_theme_name, const std::string &_to_name );

    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(uint64_t _notification_mask,
                                     std::function<void()> _callback );

private:
    const char * const m_CurrentThemePath;
    const char * const m_ThemesStoragePath;

    void LoadThemes();
    void LoadDefaultThemes();
    void WriteThemes() const;
    void UpdateCurrentTheme();

    std::string m_SelectedThemeName;
    std::unordered_map< std::string, std::shared_ptr<const nc::config::Document> > m_Themes;
    std::vector<std::string> m_OrderedThemeNames;
    std::unordered_map< std::string, std::shared_ptr<const nc::config::Document> > m_DefaultThemes;
    std::vector<std::string> m_OrderedDefaultThemeNames;
    ObservationTicket m_AppearanceObservation;
};
