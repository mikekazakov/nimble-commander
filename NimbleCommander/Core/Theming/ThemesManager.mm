// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/rapidjson.h>
#include "Theme.h"
#include "CocoaAppearanceManager.h"
#include "ThemesManager.h"

static const auto g_NameKey = "themeName";

static shared_ptr<Theme> g_CurrentTheme;

using TMN = ThemesManager::Notifications;
static const fixed_eytzinger_map<string, uint64_t> g_EntryToNotificationMapping = {
{"themeAppearance", TMN::Appearance },
{"filePanelsColoringRules_v1",          TMN::FilePanelsGeneral },
{"filePanelsGeneralDropBorderColor",    TMN::FilePanelsGeneral },
{"filePanelsGeneralOverlayColor",       TMN::FilePanelsGeneral },
{"filePanelsGeneralSplitterColor",      TMN::FilePanelsGeneral },
{"filePanelsGeneralTopSeparatorColor",  TMN::FilePanelsGeneral },
{"filePanelsTabsFont",                                  TMN::FilePanelsTabs },
{"filePanelsTabsTextColor",                             TMN::FilePanelsTabs },
{"filePanelsTabsSelectedKeyWndActiveBackgroundColor",   TMN::FilePanelsTabs },
{"filePanelsTabsSelectedKeyWndInactiveBackgroundColor", TMN::FilePanelsTabs },
{"filePanelsTabsSelectedNotKeyWndBackgroundColor",      TMN::FilePanelsTabs },
{"filePanelsTabsRegularKeyWndHoverBackgroundColor",     TMN::FilePanelsTabs },
{"filePanelsTabsRegularKeyWndRegularBackgroundColor",   TMN::FilePanelsTabs },
{"filePanelsTabsRegularNotKeyWndBackgroundColor",       TMN::FilePanelsTabs },
{"filePanelsTabsSeparatorColor",                        TMN::FilePanelsTabs },
{"filePanelsTabsPictogramColor",                        TMN::FilePanelsTabs },
{"filePanelsHeaderFont",                    TMN::FilePanelsHeader },
{"filePanelsHeaderTextColor",               TMN::FilePanelsHeader },
{"filePanelsHeaderActiveTextColor",         TMN::FilePanelsHeader },
{"filePanelsHeaderActiveBackgroundColor",   TMN::FilePanelsHeader },
{"filePanelsHeaderInactiveBackgroundColor", TMN::FilePanelsHeader },
{"filePanelsHeaderSeparatorColor",          TMN::FilePanelsHeader },
{"filePanelsFooterFont",                    TMN::FilePanelsFooter },
{"filePanelsFooterTextColor",               TMN::FilePanelsFooter },
{"filePanelsFooterActiveTextColor",         TMN::FilePanelsFooter },
{"filePanelsFooterSeparatorsColor",         TMN::FilePanelsFooter },
{"filePanelsFooterActiveBackgroundColor",   TMN::FilePanelsFooter },
{"filePanelsFooterInactiveBackgroundColor", TMN::FilePanelsFooter },
{"filePanelsListFont",                                  TMN::FilePanelsList },
{"filePanelsListGridColor",                             TMN::FilePanelsList },
{"filePanelsListHeaderFont",                            TMN::FilePanelsList },
{"filePanelsListHeaderBackgroundColor",                 TMN::FilePanelsList },
{"filePanelsListHeaderTextColor",                       TMN::FilePanelsList },
{"filePanelsListHeaderSeparatorColor",                  TMN::FilePanelsList },
{"filePanelsListFocusedActiveRowBackgroundColor",       TMN::FilePanelsList },
{"filePanelsListFocusedInactiveRowBackgroundColor",     TMN::FilePanelsList },
{"filePanelsListRegularEvenRowBackgroundColor",         TMN::FilePanelsList },
{"filePanelsListRegularOddRowBackgroundColor",          TMN::FilePanelsList },
{"filePanelsListSelectedItemBackgroundColor",           TMN::FilePanelsList },
{"filePanelsBriefFont",                                 TMN::FilePanelsBrief },
{"filePanelsBriefGridColor",                            TMN::FilePanelsBrief },
{"filePanelsBriefRegularEvenRowBackgroundColor",        TMN::FilePanelsBrief },
{"filePanelsBriefRegularOddRowBackgroundColor",         TMN::FilePanelsBrief },
{"filePanelsBriefFocusedActiveItemBackgroundColor",     TMN::FilePanelsBrief },
{"filePanelsBriefFocusedInactiveItemBackgroundColor",   TMN::FilePanelsBrief },
{"filePanelsBriefSelectedItemBackgroundColor",          TMN::FilePanelsBrief },
{"terminalFont",                TMN::Terminal },
{"terminalOverlayColor",        TMN::Terminal },
{"terminalForegroundColor",     TMN::Terminal },
{"terminalBoldForegroundColor", TMN::Terminal },
{"terminalBackgroundColor",     TMN::Terminal },
{"terminalSelectionColor",      TMN::Terminal },
{"terminalCursorColor",         TMN::Terminal },
{"terminalAnsiColor0",          TMN::Terminal },
{"terminalAnsiColor1",          TMN::Terminal },
{"terminalAnsiColor2",          TMN::Terminal },
{"terminalAnsiColor3",          TMN::Terminal },
{"terminalAnsiColor4",          TMN::Terminal },
{"terminalAnsiColor5",          TMN::Terminal },
{"terminalAnsiColor6",          TMN::Terminal },
{"terminalAnsiColor7",          TMN::Terminal },
{"terminalAnsiColor8",          TMN::Terminal },
{"terminalAnsiColor9",          TMN::Terminal },
{"terminalAnsiColorA",          TMN::Terminal },
{"terminalAnsiColorB",          TMN::Terminal },
{"terminalAnsiColorC",          TMN::Terminal },
{"terminalAnsiColorD",          TMN::Terminal },
{"terminalAnsiColorE",          TMN::Terminal },
{"terminalAnsiColorF",          TMN::Terminal },
{"viewerFont",              TMN::Viewer },
{"viewerOverlayColor",      TMN::Viewer },
{"viewerTextColor",         TMN::Viewer },
{"viewerSelectionColor",    TMN::Viewer },
{"viewerBackgroundColor",   TMN::Viewer },
};

ThemesManager::ThemesManager( const char *_current_theme_path, const char *_themes_storage_path ):
    m_CurrentThemePath(_current_theme_path),
    m_ThemesStoragePath(_themes_storage_path)
{
    LoadDefaultThemes();
    LoadThemes();
    m_SelectedThemeName = GlobalConfig().GetString(m_CurrentThemePath).value_or("Modern");
    
    UpdateCurrentTheme();
    
    m_AppearanceObservation = ObserveChanges(Notifications::Appearance, []{
        CocoaAppearanceManager::Instance().UpdateCurrentAppearance();
    });
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
        if( m_Themes.count(name) )
            continue; // broken config - duplicate theme declaration, prohibit such stuff
        
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
        m_OrderedDefaultThemeNames.emplace_back( name );
    }
}

string ThemesManager::SelectedThemeName() const
{
    return m_SelectedThemeName;
}

shared_ptr<const rapidjson::StandaloneValue> ThemesManager::SelectedThemeData() const
{
    auto i = ThemeData( m_SelectedThemeName );
    if( i->GetType() == rapidjson::kObjectType )
        return i;
    
    // at this moment there's some inconsistency in config, lets use a failsafe Modern theme.
    return BackupThemeData( "Modern" );
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

shared_ptr<const rapidjson::StandaloneValue> ThemesManager::
    BackupThemeData(const string &_theme_name) const
{
    auto i = m_DefaultThemes.find( _theme_name );
    if( i != end(m_DefaultThemes) )
        return i->second;
    
    i = m_DefaultThemes.find( "Modern" );
    if( i != end(m_DefaultThemes) )
        return i->second;
    
    assert( "default config is corrupted, there's no Modern theme" == nullptr );
}

static uint64_t NotificationMaskForKey( const string &_key )
{
    const auto it = g_EntryToNotificationMapping.find( _key );
    return it != end(g_EntryToNotificationMapping) ? it->second : 0;
}

bool ThemesManager::SetThemeValue(const string &_theme_name,
                                  const string &_key,
                                  const rapidjson::StandaloneValue &_value)
{
    auto it = m_Themes.find( _theme_name );
    if( it == end(m_Themes) )
        return false;
    
    auto &d = *it->second;
    
    if( d.HasMember(_key.c_str()) )
        if( d[_key.c_str()] == _value )
            return true;
    
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
    return true;
}


void ThemesManager::UpdateCurrentTheme()
{
    // comprose new theme object
    auto theme_data = SelectedThemeData();
    auto new_theme = make_shared<Theme>((const void*)theme_data.get(),
                                        (const void*)BackupThemeData(m_SelectedThemeName).get());

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
    
    if( !m_Themes.count(_theme_name) )
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

bool ThemesManager::ImportThemeData(const string &_theme_name,
                                    const rapidjson::StandaloneValue &_data)
{
    if( _data.GetType() != rapidjson::kObjectType )
        return false;

    auto it = m_Themes.find( _theme_name );
    if( it == end(m_Themes) )
        return false;
    
    auto &old_doc = *it->second;
    
    rapidjson::StandaloneDocument new_doc;
    new_doc.CopyFrom( old_doc, rapidjson::g_CrtAllocator );
    
    bool any = false;
    uint64_t changes_mask = 0;
    for( auto i = _data.MemberBegin(), e = _data.MemberEnd(); i != e; ++i ) {
        if( i->name == g_NameKey )
            continue;
        
        if( new_doc.HasMember(i->name) )
            if( new_doc[i->name] == i->value )
                continue;
        
        new_doc.RemoveMember( i->name );
        new_doc.AddMember(rapidjson::MakeStandaloneString(i->name.GetString()),
                          rapidjson::StandaloneValue(i->value, rapidjson::g_CrtAllocator),
                          rapidjson::g_CrtAllocator);
        changes_mask |= NotificationMaskForKey( i->name.GetString() );
        any = true;
    }
    
    if( !any )
        return false;
    
    // put new data into our working dictionary
    it->second = make_shared<rapidjson::StandaloneDocument>( move(new_doc) );
    
    // if this is a selected theme
    if( _theme_name == m_SelectedThemeName ) {
        UpdateCurrentTheme();
        FireObservers( changes_mask );
    }
    
    // TODO: move to background thread, delay execution
    WriteThemes();

    return true;
}

bool ThemesManager::AddTheme(const string &_theme_name,
                             const rapidjson::StandaloneValue &_data)
{
    if( _theme_name.empty() || m_Themes.count(_theme_name) )
        return false;
    
    rapidjson::StandaloneDocument doc;
    doc.CopyFrom(_data, rapidjson::g_CrtAllocator);
    
    doc.RemoveMember( g_NameKey );
    doc.AddMember(rapidjson::MakeStandaloneString(g_NameKey),
                  rapidjson::MakeStandaloneString(_theme_name),
                  rapidjson::g_CrtAllocator);
    
    m_Themes.emplace( _theme_name, make_shared<rapidjson::StandaloneDocument>( move(doc) ) );
    m_OrderedThemeNames.emplace_back( _theme_name );

    // TODO: move to background thread, delay execution
    WriteThemes();
    
    return true;
}

string ThemesManager::SuitableNameForNewTheme( const string &_current_theme_name ) const
{
    const auto themes = ThemeNames();
    
    for( int i = 1; i < 99; ++i ) {
        const auto v = i == 1 ? _current_theme_name : _current_theme_name + " " + to_string(i);
        if( find(begin(themes), end(themes), v) == end(themes) )
            return v;
    }
    return "";
}

bool ThemesManager::CanBeRemoved( const string &_theme_name ) const
{
    return m_Themes.count(_theme_name) && !HasDefaultSettings( _theme_name );
}

bool ThemesManager::RemoveTheme( const string &_theme_name )
{
    if( !CanBeRemoved(_theme_name) )
        return false;
    
    m_Themes.erase( _theme_name );
    
    auto otni = find(begin(m_OrderedThemeNames), end(m_OrderedThemeNames), _theme_name);
    if( otni != end(m_OrderedThemeNames) )
        m_OrderedThemeNames.erase(otni);

    // TODO: move to background thread, delay execution
    WriteThemes();

    if( m_SelectedThemeName == _theme_name )
        SelectTheme( m_OrderedDefaultThemeNames.at(0) );
    
    return true;
}

bool ThemesManager::CanBeRenamed( const string &_theme_name ) const
{
    return m_Themes.count(_theme_name) && !HasDefaultSettings( _theme_name );
}

bool ThemesManager::RenameTheme( const string &_theme_name, const string &_to_name )
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
    
    rapidjson::StandaloneDocument doc;
    doc.CopyFrom(*old_doc, rapidjson::g_CrtAllocator);
    
    doc.RemoveMember( g_NameKey );
    doc.AddMember(rapidjson::MakeStandaloneString(g_NameKey),
                  rapidjson::MakeStandaloneString(_to_name),
                  rapidjson::g_CrtAllocator);
    
    m_Themes.erase(_theme_name);
    m_Themes.emplace( _to_name, make_shared<rapidjson::StandaloneDocument>( move(doc) ) );
    replace( begin(m_OrderedThemeNames), end(m_OrderedThemeNames), _theme_name, _to_name );
    

    // TODO: move to background thread, delay execution
    WriteThemes();

    if( m_SelectedThemeName == _theme_name )
        SelectTheme( _to_name );

    return true;
}
