#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include <fstream>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>
#include "Theme.h"

const Theme &CurrentTheme()
{
// get ThemesManager instance
// ask for current theme
// return it
    static Theme t(nullptr);
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
    const auto theme = GlobalConfig().GetString("general.theme").value_or("modern");
    const auto bundle_path = [NSBundle.mainBundle
        pathForResource:[NSString stringWithUTF8StdString:theme]
                 ofType:@"json"
    ];
    const auto supp_path = AppDelegate.me.supportDirectory + theme + ".json";
    const string json = access(supp_path.c_str(), R_OK) == 0 ?
        Load(supp_path) :
        Load(bundle_path.fileSystemRepresentationSafe);
    
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

struct Theme::Internals
{
    ThemeAppearance m_ThemeAppearanceType;
    NSAppearance *m_Appearance;

    vector<PanelViewPresentationItemsColoringRule> m_ColoringRules;
    NSColor *m_FilePanelsGeneralDropBorderColor;
    NSColor *m_FilePanelsGeneralOverlayColor;
    NSFont  *m_FilePanelsHeaderFont;
    NSColor *m_FilePanelsHeaderTextColor;
    NSColor *m_FilePanelsHeaderActiveTextColor;
    NSColor *m_FilePanelsHeaderActiveBackgroundColor;
    NSColor *m_FilePanelsHeaderInactiveBackgroundColor;
    NSColor *m_FilePanelsHeaderSeparatorColor;
    NSFont  *m_FilePanelsFooterFont;
    NSColor *m_FilePanelsFooterTextColor;
    NSColor *m_FilePanelsFooterActiveTextColor;
    NSColor *m_FilePanelsFooterSeparatorsColor;
    NSColor *m_FilePanelsFooterActiveBackgroundColor;
    NSColor *m_FilePanelsFooterInactiveBackgroundColor;
    NSFont  *m_FilePanelsTabsFont;
    NSColor *m_FilePanelsTabsTextColor;
    NSColor *m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor;
    NSColor *m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor;
    NSColor *m_FilePanelsTabsSelectedNotKeyWndBackgroundColor;
    NSColor *m_FilePanelsTabsRegularKeyWndHoverBackgroundColor;
    NSColor *m_FilePanelsTabsRegularKeyWndRegularBackgroundColor;
    NSColor *m_FilePanelsTabsRegularNotKeyWndBackgroundColor;
    NSColor *m_FilePanelsTabsSeparatorColor;
    NSColor *m_FilePanelsTabsPictogramColor;
    NSFont  *m_FilePanelsListFont;
    NSColor *m_FilePanelsListGridColor;
    NSFont  *m_FilePanelsListHeaderFont;
    NSColor *m_FilePanelsListHeaderBackgroundColor;
    NSColor *m_FilePanelsListHeaderTextColor;
    NSColor *m_FilePanelsListHeaderSeparatorColor;
    NSColor *m_FilePanelsListSelectedActiveRowBackgroundColor;
    NSColor *m_FilePanelsListSelectedInactiveRowBackgroundColor;
    NSColor *m_FilePanelsListRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsListRegularOddRowBackgroundColor;
    NSFont  *m_FilePanelsBriefFont;
    NSColor *m_FilePanelsBriefRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsBriefRegularOddRowBackgroundColor;
    NSColor *m_FilePanelsBriefSelectedActiveItemBackgroundColor;
    NSColor *m_FilePanelsBriefSelectedInactiveItemBackgroundColor;
    NSFont  *m_TerminalFont;
    NSColor *m_TerminalForegroundColor;
    NSColor *m_TerminalBoldForegroundColor;
    NSColor *m_TerminalBackgroundColor;
    NSColor *m_TerminalSelectionColor;
    NSColor *m_TerminalCursorColor;
    NSColor *m_TerminalAnsiColor0;
    NSColor *m_TerminalAnsiColor1;
    NSColor *m_TerminalAnsiColor2;
    NSColor *m_TerminalAnsiColor3;
    NSColor *m_TerminalAnsiColor4;
    NSColor *m_TerminalAnsiColor5;
    NSColor *m_TerminalAnsiColor6;
    NSColor *m_TerminalAnsiColor7;
    NSColor *m_TerminalAnsiColor8;
    NSColor *m_TerminalAnsiColor9;
    NSColor *m_TerminalAnsiColorA;
    NSColor *m_TerminalAnsiColorB;
    NSColor *m_TerminalAnsiColorC;
    NSColor *m_TerminalAnsiColorD;
    NSColor *m_TerminalAnsiColorE;
    NSColor *m_TerminalAnsiColorF;
};

Theme::Theme(void*_dont_call_me_exclamation_mark):
    I( make_unique<Internals>() )
{
    const auto doc = GetDocument();
    
    I->m_ThemeAppearanceType = [&]{
        auto cr = doc.FindMember("themeAppearance");
        if( cr == doc.MemberEnd() )
            return ThemeAppearance::Light;
        
        if( !cr->value.IsString() )
            return ThemeAppearance::Light;
        
        if( "aqua"s == cr->value.GetString() )
            return ThemeAppearance::Light;
        if( "dark"s == cr->value.GetString() )
            return ThemeAppearance::Dark;
    
        return ThemeAppearance::Light;
    }();
    I->m_Appearance = I->m_ThemeAppearanceType == ThemeAppearance::Light ?
        [NSAppearance appearanceNamed:NSAppearanceNameAqua] :
        [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];

    auto cr = &doc.FindMember("filePanelsColoringRules_v1")->value;
    if( cr->IsArray() )
        for( auto i = cr->Begin(), e = cr->End(); i != e; ++i ) {
            auto v = GenericConfig::ConfigValue( *i, rapidjson::g_CrtAllocator );
            I->m_ColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(v) );
        }
    I->m_ColoringRules.emplace_back(); // always have a default ("others") non-filtering filter at the back
    
    I->m_FilePanelsGeneralDropBorderColor =
        ExtractColor(doc, "filePanelsGeneralDropBorderColor");
    I->m_FilePanelsGeneralOverlayColor =
        ExtractColor(doc, "filePanelsGeneralOverlayColor");
    
    I->m_FilePanelsListFont =
        ExtractFont(doc, "filePanelsListFont");
    I->m_FilePanelsListGridColor =
        ExtractColor(doc, "filePanelsListGridColor");
    
    I->m_FilePanelsHeaderFont =
        ExtractFont(doc, "filePanelsHeaderFont");
    I->m_FilePanelsHeaderTextColor =
        ExtractColor(doc, "filePanelsHeaderTextColor");
    I->m_FilePanelsHeaderActiveTextColor =
        ExtractColor(doc, "filePanelsHeaderActiveTextColor");
    I->m_FilePanelsHeaderActiveBackgroundColor =
        ExtractColor(doc, "filePanelsHeaderActiveBackgroundColor");
    I->m_FilePanelsHeaderInactiveBackgroundColor =
        ExtractColor(doc, "filePanelsHeaderInactiveBackgroundColor");
    I->m_FilePanelsHeaderSeparatorColor =
        ExtractColor(doc, "filePanelsHeaderSeparatorColor");
    
    
    I->m_FilePanelsListHeaderFont =
        ExtractFont(doc, "filePanelsListHeaderFont");
    I->m_FilePanelsListHeaderBackgroundColor =
        ExtractColor(doc, "filePanelsListHeaderBackgroundColor");
    I->m_FilePanelsListHeaderTextColor =
        ExtractColor(doc, "filePanelsListHeaderTextColor");
    I->m_FilePanelsListHeaderSeparatorColor =
        ExtractColor(doc, "filePanelsListHeaderSeparatorColor");
    I->m_FilePanelsListSelectedActiveRowBackgroundColor =
        ExtractColor(doc, "filePanelsListSelectedActiveRowBackgroundColor");
    I->m_FilePanelsListSelectedInactiveRowBackgroundColor =
        ExtractColor(doc, "filePanelsListSelectedInactiveRowBackgroundColor");
    I->m_FilePanelsListRegularEvenRowBackgroundColor =
        ExtractColor(doc, "filePanelsListRegularEvenRowBackgroundColor");
    I->m_FilePanelsListRegularOddRowBackgroundColor =
        ExtractColor(doc, "filePanelsListRegularOddRowBackgroundColor");

    I->m_FilePanelsFooterFont =
        ExtractFont(doc, "filePanelsFooterFont");
    I->m_FilePanelsFooterTextColor =
        ExtractColor(doc, "filePanelsFooterTextColor");
    I->m_FilePanelsFooterActiveTextColor =
        ExtractColor(doc, "filePanelsFooterActiveTextColor");
    I->m_FilePanelsFooterSeparatorsColor =
        ExtractColor(doc, "filePanelsFooterSeparatorsColor");
    I->m_FilePanelsFooterActiveBackgroundColor =
        ExtractColor(doc, "filePanelsFooterActiveBackgroundColor");
    I->m_FilePanelsFooterInactiveBackgroundColor =
        ExtractColor(doc, "filePanelsFooterInactiveBackgroundColor");
    
    I->m_FilePanelsTabsFont =
        ExtractFont(doc, "filePanelsTabsFont");
    I->m_FilePanelsTabsTextColor =
        ExtractColor(doc, "filePanelsTabsTextColor");
    I->m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor =
        ExtractColor(doc, "filePanelsTabsSelectedKeyWndActiveBackgroundColor");
    I->m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor =
        ExtractColor(doc, "filePanelsTabsSelectedKeyWndInactiveBackgroundColor");
    I->m_FilePanelsTabsSelectedNotKeyWndBackgroundColor =
        ExtractColor(doc, "filePanelsTabsSelectedNotKeyWndBackgroundColor");
    I->m_FilePanelsTabsRegularKeyWndHoverBackgroundColor =
        ExtractColor(doc, "filePanelsTabsRegularKeyWndHoverBackgroundColor");
    I->m_FilePanelsTabsRegularKeyWndRegularBackgroundColor =
        ExtractColor(doc, "filePanelsTabsRegularKeyWndRegularBackgroundColor");
    I->m_FilePanelsTabsRegularNotKeyWndBackgroundColor =
        ExtractColor(doc, "filePanelsTabsRegularNotKeyWndBackgroundColor");
    I->m_FilePanelsTabsSeparatorColor =
        ExtractColor(doc, "filePanelsTabsSeparatorColor");
    I->m_FilePanelsTabsPictogramColor =
        ExtractColor(doc, "filePanelsTabsPictogramColor");
    
    I->m_FilePanelsBriefFont =
        ExtractFont(doc, "filePanelsBriefFont");
    I->m_FilePanelsBriefRegularEvenRowBackgroundColor =
        ExtractColor(doc, "filePanelsBriefRegularEvenRowBackgroundColor");
    I->m_FilePanelsBriefRegularOddRowBackgroundColor =
        ExtractColor(doc, "filePanelsBriefRegularOddRowBackgroundColor");
    I->m_FilePanelsBriefSelectedActiveItemBackgroundColor =
        ExtractColor(doc, "filePanelsBriefSelectedActiveItemBackgroundColor");
    I->m_FilePanelsBriefSelectedInactiveItemBackgroundColor =
        ExtractColor(doc, "filePanelsBriefSelectedInactiveItemBackgroundColor");
    
    I->m_TerminalFont =
        ExtractFont(doc, "terminalFont");
    I->m_TerminalForegroundColor =
        ExtractColor(doc, "terminalForegroundColor");
    I->m_TerminalBoldForegroundColor =
        ExtractColor(doc, "terminalBoldForegroundColor");
    I->m_TerminalBackgroundColor =
        ExtractColor(doc, "terminalBackgroundColor");
    I->m_TerminalSelectionColor =
        ExtractColor(doc, "terminalSelectionColor");
    I->m_TerminalCursorColor =
        ExtractColor(doc, "terminalCursorColor");
    I->m_TerminalAnsiColor0 =
        ExtractColor(doc, "terminalAnsiColor0");
    I->m_TerminalAnsiColor1 =
        ExtractColor(doc, "terminalAnsiColor1");
    I->m_TerminalAnsiColor2 =
        ExtractColor(doc, "terminalAnsiColor2");
    I->m_TerminalAnsiColor3 =
        ExtractColor(doc, "terminalAnsiColor3");
    I->m_TerminalAnsiColor4 =
        ExtractColor(doc, "terminalAnsiColor4");
    I->m_TerminalAnsiColor5 =
        ExtractColor(doc, "terminalAnsiColor5");
    I->m_TerminalAnsiColor6 =
        ExtractColor(doc, "terminalAnsiColor6");
    I->m_TerminalAnsiColor7 =
        ExtractColor(doc, "terminalAnsiColor7");
    I->m_TerminalAnsiColor8 =
        ExtractColor(doc, "terminalAnsiColor8");
    I->m_TerminalAnsiColor9 =
        ExtractColor(doc, "terminalAnsiColor9");
    I->m_TerminalAnsiColorA =
        ExtractColor(doc, "terminalAnsiColorA");
    I->m_TerminalAnsiColorB =
        ExtractColor(doc, "terminalAnsiColorB");
    I->m_TerminalAnsiColorC =
        ExtractColor(doc, "terminalAnsiColorC");
    I->m_TerminalAnsiColorD =
        ExtractColor(doc, "terminalAnsiColorD");
    I->m_TerminalAnsiColorE =
        ExtractColor(doc, "terminalAnsiColorE");
    I->m_TerminalAnsiColorF =
        ExtractColor(doc, "terminalAnsiColorF");
}

Theme::~Theme()
{
}

ThemeAppearance Theme::AppearanceType() const noexcept
{
    return I->m_ThemeAppearanceType;
}

NSAppearance *Theme::Appearance() const noexcept
{
    return I->m_Appearance;
}

NSFont *Theme::FilePanelsListFont() const noexcept
{
    return I->m_FilePanelsListFont;
}

NSColor *Theme::FilePanelsListSelectedActiveRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListSelectedActiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListSelectedInactiveRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListSelectedInactiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListRegularEvenRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListRegularEvenRowBackgroundColor;
}

NSColor *Theme::FilePanelsListRegularOddRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListRegularOddRowBackgroundColor;
}

NSColor *Theme::FilePanelsGeneralDropBorderColor() const noexcept
{
    return I->m_FilePanelsGeneralDropBorderColor;
}

const vector<Theme::ColoringRules>& Theme::FilePanelsItemsColoringRules() const noexcept
{
    return I->m_ColoringRules;
}

NSColor *Theme::FilePanelsFooterActiveBackgroundColor() const noexcept
{
    return I->m_FilePanelsFooterActiveBackgroundColor;
}

NSColor *Theme::FilePanelsFooterInactiveBackgroundColor() const noexcept
{
    return I->m_FilePanelsFooterInactiveBackgroundColor;
}

NSColor *Theme::FilePanelsFooterTextColor() const noexcept
{
    return I->m_FilePanelsFooterTextColor;
}

NSColor *Theme::FilePanelsFooterSeparatorsColor() const noexcept
{
    return I->m_FilePanelsFooterSeparatorsColor;
}

NSColor *Theme::FilePanelsListGridColor() const noexcept
{
    return I->m_FilePanelsListGridColor;
}

NSColor *Theme::FilePanelsFooterActiveTextColor() const noexcept
{
    return I->m_FilePanelsFooterActiveTextColor;
}

NSFont  *Theme::FilePanelsFooterFont() const noexcept
{
    return I->m_FilePanelsFooterFont;
}

NSColor *Theme::FilePanelsListHeaderBackgroundColor() const noexcept
{
    return I->m_FilePanelsListHeaderBackgroundColor;
}

NSColor *Theme::FilePanelsListHeaderTextColor() const noexcept
{
    return I->m_FilePanelsListHeaderTextColor;
}

NSFont  *Theme::FilePanelsListHeaderFont() const noexcept
{
    return I->m_FilePanelsListHeaderFont;
}

NSColor *Theme::FilePanelsHeaderActiveBackgroundColor() const noexcept
{
    return I->m_FilePanelsHeaderActiveBackgroundColor;
}

NSColor *Theme::FilePanelsHeaderInactiveBackgroundColor() const noexcept
{
    return I->m_FilePanelsHeaderInactiveBackgroundColor;
}

NSFont  *Theme::FilePanelsHeaderFont() const noexcept
{
    return I->m_FilePanelsHeaderFont;
}

NSColor *Theme::FilePanelsTabsSelectedKeyWndActiveBackgroundColor() const noexcept
{
    return I->m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor;
}

NSColor *Theme::FilePanelsTabsSelectedKeyWndInactiveBackgroundColor() const noexcept
{
    return I->m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor;
}

NSColor *Theme::FilePanelsTabsSelectedNotKeyWndBackgroundColor() const noexcept
{
    return I->m_FilePanelsTabsSelectedNotKeyWndBackgroundColor;
}

NSColor *Theme::FilePanelsTabsRegularKeyWndHoverBackgroundColor() const noexcept
{
    return I->m_FilePanelsTabsRegularKeyWndHoverBackgroundColor;
}

NSColor *Theme::FilePanelsTabsRegularKeyWndRegularBackgroundColor() const noexcept
{
    return I->m_FilePanelsTabsRegularKeyWndRegularBackgroundColor;
}

NSColor *Theme::FilePanelsTabsRegularNotKeyWndBackgroundColor() const noexcept
{
    return I->m_FilePanelsTabsRegularNotKeyWndBackgroundColor;
}

NSColor *Theme::FilePanelsTabsSeparatorColor() const noexcept
{
    return I->m_FilePanelsTabsSeparatorColor;
}

NSFont  *Theme::FilePanelsTabsFont() const noexcept
{
    return I->m_FilePanelsTabsFont;
}

NSColor *Theme::FilePanelsTabsTextColor() const noexcept
{
    return I->m_FilePanelsTabsTextColor;
}

NSColor *Theme::FilePanelsTabsPictogramColor() const noexcept
{
    return I->m_FilePanelsTabsPictogramColor;
}

NSColor *Theme::FilePanelsHeaderTextColor() const noexcept
{
    return I->m_FilePanelsHeaderTextColor;
}

NSColor *Theme::FilePanelsHeaderActiveTextColor() const noexcept
{
    return I->m_FilePanelsHeaderActiveTextColor;
}

NSColor *Theme::FilePanelsListHeaderSeparatorColor() const noexcept
{
    return I->m_FilePanelsListHeaderSeparatorColor;
}

NSColor *Theme::FilePanelsHeaderSeparatorColor() const noexcept
{
    return I->m_FilePanelsHeaderSeparatorColor;
}

NSFont  *Theme::FilePanelsBriefFont() const noexcept
{
    return I->m_FilePanelsBriefFont;
}

NSColor *Theme::FilePanelsBriefRegularEvenRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefRegularEvenRowBackgroundColor;
}

NSColor *Theme::FilePanelsBriefRegularOddRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefRegularOddRowBackgroundColor;
}

NSColor *Theme::FilePanelsBriefSelectedActiveItemBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefSelectedActiveItemBackgroundColor;
}

NSColor *Theme::FilePanelsBriefSelectedInactiveItemBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefSelectedInactiveItemBackgroundColor;
}

NSColor *Theme::FilePanelsGeneralOverlayColor() const noexcept
{
    return I->m_FilePanelsGeneralOverlayColor;
}

NSFont  *Theme::TerminalFont() const noexcept
{
    return I->m_TerminalFont;
}

NSColor *Theme::TerminalForegroundColor() const noexcept
{
    return I->m_TerminalForegroundColor;
}

NSColor *Theme::TerminalBoldForegroundColor() const noexcept
{
    return I->m_TerminalBoldForegroundColor;
}

NSColor *Theme::TerminalBackgroundColor() const noexcept
{
    return I->m_TerminalBackgroundColor;
}

NSColor *Theme::TerminalSelectionColor() const noexcept
{
    return I->m_TerminalSelectionColor;
}

NSColor *Theme::TerminalCursorColor() const noexcept
{
    return I->m_TerminalCursorColor;
}

NSColor *Theme::TerminalAnsiColor0() const noexcept
{
    return I->m_TerminalAnsiColor0;
}

NSColor *Theme::TerminalAnsiColor1() const noexcept
{
    return I->m_TerminalAnsiColor1;
}

NSColor *Theme::TerminalAnsiColor2() const noexcept
{
    return I->m_TerminalAnsiColor2;
}

NSColor *Theme::TerminalAnsiColor3() const noexcept
{
    return I->m_TerminalAnsiColor3;
}

NSColor *Theme::TerminalAnsiColor4() const noexcept
{
    return I->m_TerminalAnsiColor4;
}

NSColor *Theme::TerminalAnsiColor5() const noexcept
{
    return I->m_TerminalAnsiColor5;
}

NSColor *Theme::TerminalAnsiColor6() const noexcept
{
    return I->m_TerminalAnsiColor6;
}

NSColor *Theme::TerminalAnsiColor7() const noexcept
{
    return I->m_TerminalAnsiColor7;
}

NSColor *Theme::TerminalAnsiColor8() const noexcept
{
    return I->m_TerminalAnsiColor8;
}

NSColor *Theme::TerminalAnsiColor9() const noexcept
{
    return I->m_TerminalAnsiColor9;
}

NSColor *Theme::TerminalAnsiColorA() const noexcept
{
    return I->m_TerminalAnsiColorA;
}

NSColor *Theme::TerminalAnsiColorB() const noexcept
{
    return I->m_TerminalAnsiColorB;
}

NSColor *Theme::TerminalAnsiColorC() const noexcept
{
    return I->m_TerminalAnsiColorC;
}

NSColor *Theme::TerminalAnsiColorD() const noexcept
{
    return I->m_TerminalAnsiColorD;
}

NSColor *Theme::TerminalAnsiColorE() const noexcept
{
    return I->m_TerminalAnsiColorE;
}

NSColor *Theme::TerminalAnsiColorF() const noexcept
{
    return I->m_TerminalAnsiColorF;
}
