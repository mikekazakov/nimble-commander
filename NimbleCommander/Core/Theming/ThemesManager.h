#pragma once

#include <Habanero/Observable.h>
#include <NimbleCommander/Core/rapidjson.h>

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
    
    string SelectedThemeName() const;
    
    bool SelectTheme( const string &_theme_name );
    
    vector<string> ThemeNames() const;
    
    bool HasDefaultSettings( const string &_theme_name ) const;
    
    /**
     * Effectively returns ThemeData( SelectedThemeName() ).
     */
    shared_ptr<const rapidjson::StandaloneValue> SelectedThemeData() const;
    
    shared_ptr<const rapidjson::StandaloneValue> BackupThemeData( const string &_theme_name ) const;

    /**
     * May return shared ptr to kNullType.
     */
    shared_ptr<const rapidjson::StandaloneValue> ThemeData( const string &_theme_name ) const;
    
    void SetThemeValue(const string &_theme_name,
                       const string &_key,
                       const rapidjson::StandaloneValue &_value);
    
    bool DiscardThemeChanges( const string &_theme_name );

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
    ObservationTicket m_AppearanceObservation;
};
