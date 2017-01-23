#include <NimbleCommander/Bootstrap/Config.h>
#include "Theme.h"
#include "ThemesManager.h"

static const auto g_NameKey = "themeName";

static shared_ptr<Theme> g_CurrentTheme;

static unordered_map<string, uint64_t> g_EntryToNotificationMapping = {
{"filePanelsColoringRules_v1",          ThemesManager::Notifications::FilePanelsGeneral },
{"filePanelsGeneralDropBorderColor",    ThemesManager::Notifications::FilePanelsGeneral },
{"filePanelsGeneralOverlayColor",       ThemesManager::Notifications::FilePanelsGeneral },
{"filePanelsTabsFont",                                  ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsTextColor",                             ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsSelectedKeyWndActiveBackgroundColor",   ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsSelectedKeyWndInactiveBackgroundColor", ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsSelectedNotKeyWndBackgroundColor",      ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsRegularKeyWndHoverBackgroundColor",     ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsRegularKeyWndRegularBackgroundColor",   ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsRegularNotKeyWndBackgroundColor",       ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsSeparatorColor",                        ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsTabsPictogramColor",                        ThemesManager::Notifications::FilePanelsTabs },
{"filePanelsHeaderFont",                    ThemesManager::Notifications::FilePanelsHeader },
{"filePanelsHeaderTextColor",               ThemesManager::Notifications::FilePanelsHeader },
{"filePanelsHeaderActiveTextColor",         ThemesManager::Notifications::FilePanelsHeader },
{"filePanelsHeaderActiveBackgroundColor",   ThemesManager::Notifications::FilePanelsHeader },
{"filePanelsHeaderInactiveBackgroundColor", ThemesManager::Notifications::FilePanelsHeader },
{"filePanelsHeaderSeparatorColor",          ThemesManager::Notifications::FilePanelsHeader },
{"filePanelsFooterFont",                    ThemesManager::Notifications::FilePanelsFooter },
{"filePanelsFooterTextColor",               ThemesManager::Notifications::FilePanelsFooter },
{"filePanelsFooterActiveTextColor",         ThemesManager::Notifications::FilePanelsFooter },
{"filePanelsFooterSeparatorsColor",         ThemesManager::Notifications::FilePanelsFooter },
{"filePanelsFooterActiveBackgroundColor",   ThemesManager::Notifications::FilePanelsFooter },
{"filePanelsFooterInactiveBackgroundColor", ThemesManager::Notifications::FilePanelsFooter },
{"filePanelsListFont",                                  ThemesManager::Notifications::FilePanelsList },
{"filePanelsListGridColor",                             ThemesManager::Notifications::FilePanelsList },
{"filePanelsListHeaderFont",                            ThemesManager::Notifications::FilePanelsList },
{"filePanelsListHeaderBackgroundColor",                 ThemesManager::Notifications::FilePanelsList },
{"filePanelsListHeaderTextColor",                       ThemesManager::Notifications::FilePanelsList },
{"filePanelsListHeaderSeparatorColor",                  ThemesManager::Notifications::FilePanelsList },
{"filePanelsListSelectedActiveRowBackgroundColor",      ThemesManager::Notifications::FilePanelsList },
{"filePanelsListSelectedInactiveRowBackgroundColor",    ThemesManager::Notifications::FilePanelsList },
{"filePanelsListRegularEvenRowBackgroundColor",         ThemesManager::Notifications::FilePanelsList },
{"filePanelsListRegularOddRowBackgroundColor",          ThemesManager::Notifications::FilePanelsList },
{"filePanelsBriefFont",                                 ThemesManager::Notifications::FilePanelsBrief },
{"filePanelsBriefRegularEvenRowBackgroundColor",        ThemesManager::Notifications::FilePanelsBrief },
{"filePanelsBriefRegularOddRowBackgroundColor",         ThemesManager::Notifications::FilePanelsBrief },
{"filePanelsBriefSelectedActiveItemBackgroundColor",    ThemesManager::Notifications::FilePanelsBrief },
{"filePanelsBriefSelectedInactiveItemBackgroundColor",  ThemesManager::Notifications::FilePanelsBrief },
{"terminalFont",                ThemesManager::Notifications::Terminal },
{"terminalOverlayColor",        ThemesManager::Notifications::Terminal },
{"terminalForegroundColor",     ThemesManager::Notifications::Terminal },
{"terminalBoldForegroundColor", ThemesManager::Notifications::Terminal },
{"terminalBackgroundColor",     ThemesManager::Notifications::Terminal },
{"terminalSelectionColor",      ThemesManager::Notifications::Terminal },
{"terminalCursorColor",         ThemesManager::Notifications::Terminal },
{"terminalAnsiColor0",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor1",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor2",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor3",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor4",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor5",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor6",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor7",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor8",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColor9",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColorA",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColorB",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColorC",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColorD",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColorE",          ThemesManager::Notifications::Terminal },
{"terminalAnsiColorF",          ThemesManager::Notifications::Terminal },
{"viewerFont",              ThemesManager::Notifications::Viewer },
{"viewerOverlayColor",      ThemesManager::Notifications::Viewer },
{"viewerTextColor",         ThemesManager::Notifications::Viewer },
{"viewerSelectionColor",    ThemesManager::Notifications::Viewer },
{"viewerBackgroundColor",   ThemesManager::Notifications::Viewer },


};

#if 0
{
                      "themeName": "Modern",
                      "themeAppearance": "aqua",

#endif

ThemesManager::ThemesManager( const char *_current_theme_path, const char *_themes_storage_path ):
    m_CurrentThemePath(_current_theme_path),
    m_ThemesStoragePath(_themes_storage_path)
{
    LoadDefaultThemes();
    LoadThemes();
    m_SelectedThemeName = GlobalConfig().GetString(m_CurrentThemePath).value_or("Modern");
    
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
        m_OrderedThemeNames.emplace_back( name );
    }
}

void ThemesManager::LoadDefaultThemes()
{
    auto themes = GlobalConfig().GetDefault(m_ThemesStoragePath);
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
        
        m_DefaultThemes.emplace( name, make_shared<rapidjson::StandaloneDocument>( move(doc) ) );
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

static uint64_t NotificationMaskForKey( const string &_key )
{
    const auto it = g_EntryToNotificationMapping.find( _key );
    return it != end(g_EntryToNotificationMapping) ? it->second : 0;
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
        if( _theme_name == m_SelectedThemeName ) {
            UpdateCurrentTheme();
            FireObservers( NotificationMaskForKey(_key) );
        }
        
        // TODO: move to background thread, delay execution
        WriteThemes();
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

vector<string> ThemesManager::ThemeNames() const
{
    return m_OrderedThemeNames;
}

// todo: move to background, need to be thread-safe
void ThemesManager::WriteThemes() const
{
    GenericConfig::ConfigValue json_themes{ rapidjson::kArrayType };
    for( auto &tn: m_OrderedThemeNames ) {
        auto i = m_Themes.find(tn);
        assert( i != end(m_Themes) );
        
        GenericConfig::ConfigValue theme{ rapidjson::kObjectType };
        theme.CopyFrom( *i->second, rapidjson::g_CrtAllocator );
        json_themes.PushBack( move(theme), rapidjson::g_CrtAllocator);
    }
    GlobalConfig().Set( m_ThemesStoragePath, json_themes );
}

bool ThemesManager::SelectTheme( const string &_theme_name )
{
    if( m_SelectedThemeName == _theme_name )
        return true;
    
    auto i = m_Themes.find(_theme_name);
    if( i == end(m_Themes) )
        return false;
    
    m_SelectedThemeName = _theme_name;
    GlobalConfig().Set( m_CurrentThemePath, m_SelectedThemeName );
    
    
    UpdateCurrentTheme();
    // figure out what has changed
    // do some magic stuff to notify everybody about changes
    
    FireObservers(); // temporary overkill solution - just rebuild everything 
    
    return true;
}

ThemesManager::ObservationTicket ThemesManager::
    ObserveChanges( uint64_t _notification_mask, function<void()> _callback )
{
    return AddObserver( move(_callback), _notification_mask );
}

bool ThemesManager::HasDefaultSettings( const string &_theme_name ) const
{
    return m_DefaultThemes.count(_theme_name) != 0;
}

bool ThemesManager::DiscardThemeChanges( const string &_theme_name )
{
    auto ci = m_Themes.find(_theme_name);
    if( ci == end(m_Themes) )
        return false;
    
    auto di = m_DefaultThemes.find(_theme_name);
    if( di == end(m_Themes) )
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
