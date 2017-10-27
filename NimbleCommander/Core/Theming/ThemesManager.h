// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/Observable.h>
#include <NimbleCommander/Core/rapidjson_fwd.h>

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
    string SelectedThemeName() const;
    
    /**
     * Changes currently selected name, updates config, updates current theme object and
     * fires notifications.
     */
    bool SelectTheme( const string &_theme_name );
    
    /**
     * Returns a list of theme names currently installed for this user.
     */
    vector<string> ThemeNames() const;
    
    /**
     * Check if this theme is one of default themes.
     */
    bool HasDefaultSettings( const string &_theme_name ) const;
    
    /**
     * Tells if this theme can be removed. Themes that are bundled this app can't.
     */
    bool CanBeRemoved( const string &_theme_name ) const;
    
    /**
     * Effectively returns ThemeData( SelectedThemeName() ).
     */
    shared_ptr<const rapidjson::StandaloneValue> SelectedThemeData() const;
    
    /**
     * Returns current json document for specified theme.
     * May return shared ptr to kNullType.
     */
    shared_ptr<const rapidjson::StandaloneValue> ThemeData( const string &_theme_name ) const;
    
    /**
     * Tries to find a default value for this theme.
     * If there's no - returns a value for Modern theme.
     */
    shared_ptr<const rapidjson::StandaloneValue> BackupThemeData( const string &_theme_name ) const;    
    
    /**
     * Changes a theme value, if theme can't be found or value is the same - returns false.
     */
    bool SetThemeValue(const string &_theme_name,
                       const string &_key,
                       const rapidjson::StandaloneValue &_value);
    
    /**
     * Performs per-element document merge, replacing values in theme named _theme_name with
     * values from _data. Any unchanged or absent in _data values are untouched.
     * Theme called _theme_name must exist upon this request.
     */
    bool ImportThemeData(const string &_theme_name,
                         const rapidjson::StandaloneValue &_data);
    
    /**
     * Insert new theme. There must be no _theme_name prior this call.
     */
    bool AddTheme(const string &_theme_name,
                  const rapidjson::StandaloneValue &_data);
    
    /**
     * Check for existing themes and tries to find a suitable name for suggested name, 
     * may add a postfix number.
     */
    string SuitableNameForNewTheme( const string &_current_theme_name ) const;
    
    /**
     * Reverts state of specified theme to default value.
     * If there's no default value for this theme or there were no changes - does
     * nothing and returns false.
     */
    bool DiscardThemeChanges( const string &_theme_name );
    
    /**
     * Deletes specified theme. Only non-default themes can be removed.
     * If it was a selected theme - changes it too.
     */
    bool RemoveTheme( const string &_theme_name );
    
    bool CanBeRenamed( const string &_theme_name ) const;
    
    /**
     * Renames specified theme to new name. If it is one of default ones - it can't be renamed.
     * If some theme named _to_name already exist - returns false.
     * If _theme_name is a selected theme - updates it too.
     */
    bool RenameTheme( const string &_theme_name, const string &_to_name );

    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges( uint64_t _notification_mask, function<void()> _callback );

private:
    const char * const m_CurrentThemePath;
    const char * const m_ThemesStoragePath;

    void LoadThemes();
    void LoadDefaultThemes();
    void WriteThemes() const;
    void UpdateCurrentTheme();

    string m_SelectedThemeName;
    unordered_map< string, shared_ptr<const rapidjson::StandaloneDocument> > m_Themes;
    vector<string> m_OrderedThemeNames;
    unordered_map< string, shared_ptr<const rapidjson::StandaloneDocument> > m_DefaultThemes;
    vector<string> m_OrderedDefaultThemeNames;
    ObservationTicket m_AppearanceObservation;
};
