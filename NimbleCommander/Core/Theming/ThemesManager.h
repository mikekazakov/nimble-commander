#pragma once

#include <NimbleCommander/Core/rapidjson.h>

/**
 * This class is not thread-safe yet!
 */
class ThemesManager
{
public:
    ThemesManager( const char *_current_theme_path, const char *_themes_storage_path );
    
    string SelectedThemeName() const;
    
    bool SelectTheme( const string &_theme_name );
    
    vector<string> ThemeNames() const;
    
    /**
     * Effectively returns ThemeData( SelectedThemeName() ).
     */
    shared_ptr<const rapidjson::StandaloneValue> SelectedThemeData() const;

    /**
     * May return shared ptr to kNullType.
     */
    shared_ptr<const rapidjson::StandaloneValue> ThemeData( const string &_theme_name ) const;
    
    void SetThemeValue(const string &_theme_name,
                       const string &_key,
                       const rapidjson::StandaloneValue &_value);

private:
    const char * const m_CurrentThemePath;
    const char * const m_ThemesStoragePath;

    void LoadThemes();
    void WriteThemes() const;
    void UpdateCurrentTheme();

    string m_SelectedThemeName;
    unordered_map< string, shared_ptr<const rapidjson::StandaloneDocument> > m_Themes;
    vector<string> m_OrderedThemeNames;
};
