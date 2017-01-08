#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include <fstream>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>
#include "Theme.h"

//#include "../PanelViewPresentationItemsColoringFilter.h"

static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";

const Theme &CurrentTheme()
{
// get ThemesManager instance
// ask for current theme
// return it
    static Theme t;
    return t;

}

static string Load(const string &_filepath)
{
    ifstream i(_filepath, ios::in | ios::binary);
    if( i ) {
        string contents;
        i.seekg( 0, ios::end );
        contents.resize( i.tellg() );
        i.seekg( 0, ios::beg );
        i.read( &contents[0], contents.size() );
        i.close();
        return contents;
    }
    return "";
}

static rapidjson::Document GetDocument()
{
    string json = Load([NSBundle.mainBundle pathForResource:@"modern" ofType:@"json"].
//    string json = Load([NSBundle.mainBundle pathForResource:@"dark" ofType:@"json"].
//    string json = Load([NSBundle.mainBundle pathForResource:@"classic" ofType:@"json"].
        fileSystemRepresentationSafe);
    rapidjson::Document doc;
    rapidjson::ParseResult ok = doc.Parse<rapidjson::kParseCommentsFlag>( json.c_str() );
    
    if (!ok) {
        fprintf(stderr, "Can't load main config. JSON parse error: %s (%zu)",
            rapidjson::GetParseError_En(ok.Code()), ok.Offset());
        exit(EXIT_FAILURE);
    }
    return doc;
}

static NSColor *ExtractColor( const rapidjson::Document &_doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSColor colorWithHexStdString:cr->value.GetString()];
}

static NSFont *ExtractFont( const rapidjson::Document &_doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSFont fontWithStringDescription:[NSString stringWithUTF8String:cr->value.GetString()]];
}

Theme::Theme()
{
    const auto doc = GetDocument();

    auto cr = &doc.FindMember("filePanelsColoringRules_v1")->value;
    if( cr->IsArray() )
        for( auto i = cr->Begin(), e = cr->End(); i != e; ++i ) {
            auto v = GenericConfig::ConfigValue( *i, rapidjson::g_CrtAllocator );
            m_ColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(v) );
        }
    m_ColoringRules.emplace_back(); // always have a default ("others") non-filtering filter at the back
    
    m_FilePanelsGeneralDropBorderColor =
        ExtractColor(doc, "filePanelsGeneralDropBorderColor");
    
    m_FilePanelsListFont =
        ExtractFont(doc, "filePanelsListFont");
    m_FilePanelsListGridColor =
        ExtractColor(doc, "filePanelsListGridColor");
    
    m_FilePanelsHeaderFont =
        ExtractFont(doc, "filePanelsHeaderFont");
    m_FilePanelsHeaderTextColor =
        ExtractColor(doc, "filePanelsHeaderTextColor");
    m_FilePanelsHeaderActiveTextColor =
        ExtractColor(doc, "filePanelsHeaderActiveTextColor");
    m_FilePanelsHeaderActiveBackgroundColor =
        ExtractColor(doc, "filePanelsHeaderActiveBackgroundColor");
    m_FilePanelsHeaderInactiveBackgroundColor =
        ExtractColor(doc, "filePanelsHeaderInactiveBackgroundColor");
    m_FilePanelsHeaderSeparatorColor =
        ExtractColor(doc, "filePanelsHeaderSeparatorColor");
    
    
    m_FilePanelsListHeaderFont =
        ExtractFont(doc, "filePanelsListHeaderFont");
    m_FilePanelsListHeaderBackgroundColor =
        ExtractColor(doc, "filePanelsListHeaderBackgroundColor");
    m_FilePanelsListHeaderTextColor =
        ExtractColor(doc, "filePanelsListHeaderTextColor");
    m_FilePanelsListHeaderSeparatorColor =
        ExtractColor(doc, "filePanelsListHeaderSeparatorColor");
    m_FilePanelsListSelectedActiveRowBackgroundColor =
        ExtractColor(doc, "filePanelsListSelectedActiveRowBackgroundColor");
    m_FilePanelsListSelectedInactiveRowBackgroundColor =
        ExtractColor(doc, "filePanelsListSelectedInactiveRowBackgroundColor");
    m_FilePanelsListRegularEvenRowBackgroundColor =
        ExtractColor(doc, "filePanelsListRegularEvenRowBackgroundColor");
    m_FilePanelsListRegularOddRowBackgroundColor =
        ExtractColor(doc, "filePanelsListRegularOddRowBackgroundColor");

    m_FilePanelsFooterFont =
        ExtractFont(doc, "filePanelsFooterFont");
    m_FilePanelsFooterTextColor =
        ExtractColor(doc, "filePanelsFooterTextColor");
    m_FilePanelsFooterActiveTextColor =
        ExtractColor(doc, "filePanelsFooterActiveTextColor");
    m_FilePanelsFooterSeparatorsColor =
        ExtractColor(doc, "filePanelsFooterSeparatorsColor");
    m_FilePanelsFooterActiveBackgroundColor =
        ExtractColor(doc, "filePanelsFooterActiveBackgroundColor");
    m_FilePanelsFooterInactiveBackgroundColor =
        ExtractColor(doc, "filePanelsFooterInactiveBackgroundColor");
    
    m_FilePanelsTabsFont =
        ExtractFont(doc, "filePanelsTabsFont");
    m_FilePanelsTabsTextColor =
        ExtractColor(doc, "filePanelsTabsTextColor");
    m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor =
        ExtractColor(doc, "filePanelsTabsSelectedKeyWndActiveBackgroundColor");
    m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor =
        ExtractColor(doc, "filePanelsTabsSelectedKeyWndInactiveBackgroundColor");
    m_FilePanelsTabsSelectedNotKeyWndBackgroundColor =
        ExtractColor(doc, "filePanelsTabsSelectedNotKeyWndBackgroundColor");
    m_FilePanelsTabsRegularKeyWndHoverBackgroundColor =
        ExtractColor(doc, "filePanelsTabsRegularKeyWndHoverBackgroundColor");
    m_FilePanelsTabsRegularKeyWndRegularBackgroundColor =
        ExtractColor(doc, "filePanelsTabsRegularKeyWndRegularBackgroundColor");
    m_FilePanelsTabsRegularNotKeyWndBackgroundColor =
        ExtractColor(doc, "filePanelsTabsRegularNotKeyWndBackgroundColor");
    m_FilePanelsTabsSeparatorColor =
        ExtractColor(doc, "filePanelsTabsSeparatorColor");
    m_FilePanelsTabsPictogramColor =
        ExtractColor(doc, "filePanelsTabsPictogramColor");
}

Theme::~Theme()
{
}

ThemeAppearance Theme::AppearanceType() const
{
    return ThemeAppearance::Light;
}

NSAppearance *Theme::Appearance() const
{
     switch( AppearanceType() ) {
        case ThemeAppearance::Light:
            return [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
        case ThemeAppearance::Dark:
            return [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
     }
}

NSFont *Theme::FilePanelsListFont() const
{
    return m_FilePanelsListFont;
}

NSColor *Theme::FilePanelsListSelectedActiveRowBackgroundColor() const
{
    return m_FilePanelsListSelectedActiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListSelectedInactiveRowBackgroundColor() const
{
    return m_FilePanelsListSelectedInactiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListRegularEvenRowBackgroundColor() const
{
    return m_FilePanelsListRegularEvenRowBackgroundColor;
}

NSColor *Theme::FilePanelsListRegularOddRowBackgroundColor() const
{
    return m_FilePanelsListRegularOddRowBackgroundColor;
}

NSColor *Theme::FilePanelsGeneralDropBorderColor() const
{
    return m_FilePanelsGeneralDropBorderColor;
}

const vector<PanelViewPresentationItemsColoringRule>& Theme::FilePanelsItemsColoringRules() const
{
    return m_ColoringRules;
}

NSColor *Theme::FilePanelsFooterActiveBackgroundColor() const
{
    return m_FilePanelsFooterActiveBackgroundColor;
}

NSColor *Theme::FilePanelsFooterInactiveBackgroundColor() const
{
    return m_FilePanelsFooterInactiveBackgroundColor;
}

NSColor *Theme::FilePanelsFooterTextColor() const
{
    return m_FilePanelsFooterTextColor;
}

NSColor *Theme::FilePanelsFooterSeparatorsColor() const
{
    return m_FilePanelsFooterSeparatorsColor;
}

NSColor *Theme::FilePanelsListGridColor() const
{
    return m_FilePanelsListGridColor;
}

NSColor *Theme::FilePanelsFooterActiveTextColor() const
{
    return m_FilePanelsFooterActiveTextColor;
}

NSFont  *Theme::FilePanelsFooterFont() const
{
    return m_FilePanelsFooterFont;
}

NSColor *Theme::FilePanelsListHeaderBackgroundColor() const
{
    return m_FilePanelsListHeaderBackgroundColor;
}

NSColor *Theme::FilePanelsListHeaderTextColor() const
{
    return m_FilePanelsListHeaderTextColor;
}

NSFont  *Theme::FilePanelsListHeaderFont() const
{
    return m_FilePanelsListHeaderFont;
}

NSColor *Theme::FilePanelsHeaderActiveBackgroundColor() const
{
    return m_FilePanelsHeaderActiveBackgroundColor;
}

NSColor *Theme::FilePanelsHeaderInactiveBackgroundColor() const
{
    return m_FilePanelsHeaderInactiveBackgroundColor;
}

NSFont  *Theme::FilePanelsHeaderFont() const
{
    return m_FilePanelsHeaderFont;
}

NSColor *Theme::FilePanelsTabsSelectedKeyWndActiveBackgroundColor() const
{
    return m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor;
}

NSColor *Theme::FilePanelsTabsSelectedKeyWndInactiveBackgroundColor() const
{
    return m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor;
}

NSColor *Theme::FilePanelsTabsSelectedNotKeyWndBackgroundColor() const
{
    return m_FilePanelsTabsSelectedNotKeyWndBackgroundColor;
}

NSColor *Theme::FilePanelsTabsRegularKeyWndHoverBackgroundColor() const
{
    return m_FilePanelsTabsRegularKeyWndHoverBackgroundColor;
}

NSColor *Theme::FilePanelsTabsRegularKeyWndRegularBackgroundColor() const
{
    return m_FilePanelsTabsRegularKeyWndRegularBackgroundColor;
}

NSColor *Theme::FilePanelsTabsRegularNotKeyWndBackgroundColor() const
{
    return m_FilePanelsTabsRegularNotKeyWndBackgroundColor;
}

NSColor *Theme::FilePanelsTabsSeparatorColor() const
{
    return m_FilePanelsTabsSeparatorColor;
}

NSFont  *Theme::FilePanelsTabsFont() const
{
    return m_FilePanelsTabsFont;
}

NSColor *Theme::FilePanelsTabsTextColor() const
{
    return m_FilePanelsTabsTextColor;
}

NSColor *Theme::FilePanelsTabsPictogramColor() const
{
    return m_FilePanelsTabsPictogramColor;
}

NSColor *Theme::FilePanelsHeaderTextColor() const
{
    return m_FilePanelsHeaderTextColor;
}

NSColor *Theme::FilePanelsHeaderActiveTextColor() const
{
    return m_FilePanelsHeaderActiveTextColor;
}

NSColor *Theme::FilePanelsListHeaderSeparatorColor() const
{
    return m_FilePanelsListHeaderSeparatorColor;
}

NSColor *Theme::FilePanelsHeaderSeparatorColor() const
{
    return m_FilePanelsHeaderSeparatorColor;
}
