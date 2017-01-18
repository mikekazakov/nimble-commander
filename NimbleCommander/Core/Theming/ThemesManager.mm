#include <NimbleCommander/Bootstrap/Config.h>
#include "Theme.h"
#include "ThemesManager.h"

static const auto g_NameKey = "themeName";

static shared_ptr<Theme> g_CurrentTheme;

ThemesManager::ThemesManager( const char *_current_theme_path, const char *_themes_storage_path ):
    m_CurrentThemePath(_current_theme_path),
    m_ThemesStoragePath(_themes_storage_path)
{
    LoadThemes();
    m_SelectedThemeName = GlobalConfig().GetString(m_CurrentThemePath).value_or("modern");
    
    UpdateCurrentTheme();
    
}

void ThemesManager::LoadThemes()
{

    auto themes = GlobalConfig().Get(m_ThemesStoragePath);
    if( !themes.IsArray() )
        return;
    
    for( auto i = themes.Begin(), e = themes.End(); i != e; ++i ) {
        if( !i->IsObject() )
            continue;
        const string name = [&]()->string{
            if( !i->HasMember(g_NameKey) || !(*i)[g_NameKey].IsString() )
                return "";
            return (*i)[g_NameKey].GetString();
        }();
        if( name.empty() )
            continue;
        
        rapidjson::StandaloneDocument doc;
        doc.CopyFrom(*i, rapidjson::g_CrtAllocator);
        
        m_Themes.emplace( name, make_shared<rapidjson::StandaloneDocument>( move(doc) ) );
    }
}

string ThemesManager::SelectedThemeName() const
{
    return m_SelectedThemeName;
}

shared_ptr<const rapidjson::StandaloneValue> ThemesManager::SelectedThemeData() const
{
    return ThemeData( m_SelectedThemeName );
}

shared_ptr<const rapidjson::StandaloneValue> ThemesManager::
    ThemeData( const string &_theme_name ) const
{
    auto it = m_Themes.find( _theme_name );
    if( it != end(m_Themes) )
        return it->second;

    static const auto dummy = make_shared<rapidjson::StandaloneValue>(rapidjson::kNullType);
    return dummy;
}

void ThemesManager::SetThemeValue(const string &_theme_name,
                                  const string &_key,
                                  const rapidjson::StandaloneValue &_value)
{
    auto it = m_Themes.find( _theme_name );
    if( it != end(m_Themes) ) {
        auto &d = *it->second;
        
        if( d.HasMember(_key.c_str()) )
            if( d[_key.c_str()] == _value )
                return;
        
        rapidjson::StandaloneDocument new_doc;
        new_doc.CopyFrom( d, rapidjson::g_CrtAllocator );
        new_doc.RemoveMember( _key.c_str() );
        new_doc.AddMember(rapidjson::MakeStandaloneString(_key),
                    rapidjson::StandaloneValue(_value, rapidjson::g_CrtAllocator),
                    rapidjson::g_CrtAllocator);
        
        it->second = make_shared<rapidjson::StandaloneDocument>( move(new_doc) );

        // if this is a selected theme
        if( _theme_name == m_SelectedThemeName )
            UpdateCurrentTheme();
    }
}

void ThemesManager::UpdateCurrentTheme()
{
    // comprose new theme object
    auto theme_data = SelectedThemeData();
    auto new_theme = make_shared<Theme>((const void*)theme_data.get());

    // release current theme some time after - dispatch release with 10s delay
    auto old_theme = g_CurrentTheme;
    dispatch_to_main_queue_after(5s, [=]()mutable{
        old_theme = nullptr;
    });
    
    // set new theme object
    g_CurrentTheme = new_theme;
}

const Theme &CurrentTheme() noexcept
{
    assert( g_CurrentTheme != nullptr );
    return *g_CurrentTheme;
}
