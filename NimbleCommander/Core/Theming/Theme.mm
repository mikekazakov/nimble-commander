#include "Utility/HexadecimalColor.h"
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
//    string json = Load([NSBundle.mainBundle pathForResource:@"modern" ofType:@"json"].
    string json = Load([NSBundle.mainBundle pathForResource:@"classic" ofType:@"json"].
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
    m_FilePanelsListSelectedActiveRowBackgroundColor =
        ExtractColor(doc, "filePanelsListSelectedActiveRowBackgroundColor");
    m_FilePanelsListSelectedInactiveRowBackgroundColor =
        ExtractColor(doc, "filePanelsListSelectedInactiveRowBackgroundColor");
    m_FilePanelsListRegularEvenRowBackgroundColor =
        ExtractColor(doc, "filePanelsListRegularEvenRowBackgroundColor");
    m_FilePanelsListRegularOddRowBackgroundColor =
        ExtractColor(doc, "filePanelsListRegularOddRowBackgroundColor");
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
    return [NSFont systemFontOfSize:13];
}

NSColor *Theme::FilePanelsListSelectedActiveRowBackgroundColor() const
{
//    return NSColor.blueColor;
    return m_FilePanelsListSelectedActiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListSelectedInactiveRowBackgroundColor() const
{
//    return NSColor.lightGrayColor;
    return m_FilePanelsListSelectedInactiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListRegularEvenRowBackgroundColor() const
{
//    return NSColor.controlAlternatingRowBackgroundColors[0];
    return m_FilePanelsListRegularEvenRowBackgroundColor;
}

NSColor *Theme::FilePanelsListRegularOddRowBackgroundColor() const
{
//    return NSColor.controlAlternatingRowBackgroundColors[1];
    return m_FilePanelsListRegularOddRowBackgroundColor;
}

NSColor *Theme::FilePanelsGeneralDropBorderColor() const
{
//    return NSColor.blueColor;
    return m_FilePanelsGeneralDropBorderColor;
}

const vector<PanelViewPresentationItemsColoringRule>& Theme::FilePanelsItemsColoringRules() const
{
    return m_ColoringRules;
}
