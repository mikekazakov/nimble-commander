// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Theme.h"
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilterPersistence.h>
#include "ThemePersistence.h"
#include <Utility/HexadecimalColor.h>
#include <Config/RapidJSON.h>

static atomic_ulong g_LastGeneration{1};

struct Theme::Internals
{
    uint64_t m_Generation;
    ThemeAppearance m_ThemeAppearanceType;
    NSAppearance *m_Appearance;

    vector<nc::panel::PresentationItemsColoringRule> m_ColoringRules;
    NSColor *m_FilePanelsGeneralDropBorderColor;
    NSColor *m_FilePanelsGeneralOverlayColor;
    NSColor *m_FilePanelsGeneralSplitterColor;
    NSColor *m_FilePanelsGeneralTopSeparatorColor;
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
    NSColor *m_FilePanelsListFocusedActiveRowBackgroundColor;
    NSColor *m_FilePanelsListFocusedInactiveRowBackgroundColor;
    NSColor *m_FilePanelsListSelectedRowBackgroundColor;
    NSColor *m_FilePanelsListRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsListRegularOddRowBackgroundColor;
    NSFont  *m_FilePanelsBriefFont;
    NSColor *m_FilePanelsBriefGridColor;
    NSColor *m_FilePanelsBriefRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsBriefRegularOddRowBackgroundColor;
    NSColor *m_FilePanelsBriefFocusedActiveItemBackgroundColor;
    NSColor *m_FilePanelsBriefFocusedInactiveItemBackgroundColor;
    NSColor *m_FilePanelsBriefSelectedItemBackgroundColor;
    NSFont  *m_TerminalFont;
    NSColor *m_TerminalOverlayColor;
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
    NSFont  *m_ViewerFont;
    NSColor *m_ViewerOverlayColor;
    NSColor *m_ViewerTextColor;
    NSColor *m_ViewerSelectionColor;
    NSColor *m_ViewerBackgroundColor;
};

Theme::Theme( const void *_theme_data, const void *_backup_theme_data ):
    I( make_unique<Internals>() )
{
    assert( _theme_data && _backup_theme_data );
    const auto &doc     = *(const nc::config::Value*)_theme_data;
    const auto &backup  = *(const nc::config::Value*)_backup_theme_data;
  
    const auto ExtractColor = [&]( const char *_path ) {
        if( auto v = ThemePersistence::ExtractColor(doc, _path) )
            return v;
        if( auto v = ThemePersistence::ExtractColor(backup, _path) )
            return v;
        return NSColor.blackColor;
    };
    const auto ExtractFont = [&]( const char *_path ) {
        if( auto v = ThemePersistence::ExtractFont(doc, _path) )
            return v;
        if( auto v = ThemePersistence::ExtractFont(backup, _path) )
            return v;
        return [NSFont systemFontOfSize:NSFont.systemFontSize];
    };
    
    I->m_Generation = g_LastGeneration++;
    
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
            auto rule = nc::panel::PresentationItemsColoringRulePersistence{}.FromJSON(*i);            
            I->m_ColoringRules.emplace_back( std::move(rule) );
        }
    // always have a default ("others") non-filtering filter at the back
    I->m_ColoringRules.emplace_back();
    
    I->m_FilePanelsGeneralDropBorderColor =
        ExtractColor("filePanelsGeneralDropBorderColor");
    I->m_FilePanelsGeneralOverlayColor =
        ExtractColor("filePanelsGeneralOverlayColor");
    I->m_FilePanelsGeneralSplitterColor =
        ExtractColor("filePanelsGeneralSplitterColor");
    I->m_FilePanelsGeneralTopSeparatorColor =
        ExtractColor("filePanelsGeneralTopSeparatorColor");
    
    I->m_FilePanelsListFont =
        ExtractFont("filePanelsListFont");
    I->m_FilePanelsListGridColor =
        ExtractColor("filePanelsListGridColor");
    
    I->m_FilePanelsHeaderFont =
        ExtractFont("filePanelsHeaderFont");
    I->m_FilePanelsHeaderTextColor =
        ExtractColor("filePanelsHeaderTextColor");
    I->m_FilePanelsHeaderActiveTextColor =
        ExtractColor("filePanelsHeaderActiveTextColor");
    I->m_FilePanelsHeaderActiveBackgroundColor =
        ExtractColor("filePanelsHeaderActiveBackgroundColor");
    I->m_FilePanelsHeaderInactiveBackgroundColor =
        ExtractColor("filePanelsHeaderInactiveBackgroundColor");
    I->m_FilePanelsHeaderSeparatorColor =
        ExtractColor("filePanelsHeaderSeparatorColor");
    
    I->m_FilePanelsListHeaderFont =
        ExtractFont("filePanelsListHeaderFont");
    I->m_FilePanelsListHeaderBackgroundColor =
        ExtractColor("filePanelsListHeaderBackgroundColor");
    I->m_FilePanelsListHeaderTextColor =
        ExtractColor("filePanelsListHeaderTextColor");
    I->m_FilePanelsListHeaderSeparatorColor =
        ExtractColor("filePanelsListHeaderSeparatorColor");
    I->m_FilePanelsListFocusedActiveRowBackgroundColor =
        ExtractColor("filePanelsListFocusedActiveRowBackgroundColor");
    I->m_FilePanelsListFocusedInactiveRowBackgroundColor =
        ExtractColor("filePanelsListFocusedInactiveRowBackgroundColor");
    I->m_FilePanelsListRegularEvenRowBackgroundColor =
        ExtractColor("filePanelsListRegularEvenRowBackgroundColor");
    I->m_FilePanelsListRegularOddRowBackgroundColor =
        ExtractColor("filePanelsListRegularOddRowBackgroundColor");
    I->m_FilePanelsListSelectedRowBackgroundColor =
        ExtractColor("filePanelsListSelectedItemBackgroundColor");

    I->m_FilePanelsFooterFont =
        ExtractFont("filePanelsFooterFont");
    I->m_FilePanelsFooterTextColor =
        ExtractColor("filePanelsFooterTextColor");
    I->m_FilePanelsFooterActiveTextColor =
        ExtractColor("filePanelsFooterActiveTextColor");
    I->m_FilePanelsFooterSeparatorsColor =
        ExtractColor("filePanelsFooterSeparatorsColor");
    I->m_FilePanelsFooterActiveBackgroundColor =
        ExtractColor("filePanelsFooterActiveBackgroundColor");
    I->m_FilePanelsFooterInactiveBackgroundColor =
        ExtractColor("filePanelsFooterInactiveBackgroundColor");
    
    I->m_FilePanelsTabsFont =
        ExtractFont("filePanelsTabsFont");
    I->m_FilePanelsTabsTextColor =
        ExtractColor("filePanelsTabsTextColor");
    I->m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor =
        ExtractColor("filePanelsTabsSelectedKeyWndActiveBackgroundColor");
    I->m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor =
        ExtractColor("filePanelsTabsSelectedKeyWndInactiveBackgroundColor");
    I->m_FilePanelsTabsSelectedNotKeyWndBackgroundColor =
        ExtractColor("filePanelsTabsSelectedNotKeyWndBackgroundColor");
    I->m_FilePanelsTabsRegularKeyWndHoverBackgroundColor =
        ExtractColor("filePanelsTabsRegularKeyWndHoverBackgroundColor");
    I->m_FilePanelsTabsRegularKeyWndRegularBackgroundColor =
        ExtractColor("filePanelsTabsRegularKeyWndRegularBackgroundColor");
    I->m_FilePanelsTabsRegularNotKeyWndBackgroundColor =
        ExtractColor("filePanelsTabsRegularNotKeyWndBackgroundColor");
    I->m_FilePanelsTabsSeparatorColor =
        ExtractColor("filePanelsTabsSeparatorColor");
    I->m_FilePanelsTabsPictogramColor =
        ExtractColor("filePanelsTabsPictogramColor");
    
    I->m_FilePanelsBriefFont =
        ExtractFont("filePanelsBriefFont");
    I->m_FilePanelsBriefGridColor =
        ExtractColor("filePanelsBriefGridColor");
    I->m_FilePanelsBriefRegularEvenRowBackgroundColor =
        ExtractColor("filePanelsBriefRegularEvenRowBackgroundColor");
    I->m_FilePanelsBriefRegularOddRowBackgroundColor =
        ExtractColor("filePanelsBriefRegularOddRowBackgroundColor");
    I->m_FilePanelsBriefFocusedActiveItemBackgroundColor =
        ExtractColor("filePanelsBriefFocusedActiveItemBackgroundColor");
    I->m_FilePanelsBriefFocusedInactiveItemBackgroundColor =
        ExtractColor("filePanelsBriefFocusedInactiveItemBackgroundColor");
    I->m_FilePanelsBriefSelectedItemBackgroundColor =
        ExtractColor("filePanelsBriefSelectedItemBackgroundColor");
    
    I->m_TerminalFont =
        ExtractFont("terminalFont");
    I->m_TerminalOverlayColor =
        ExtractColor("terminalOverlayColor");
    I->m_TerminalForegroundColor =
        ExtractColor("terminalForegroundColor");
    I->m_TerminalBoldForegroundColor =
        ExtractColor("terminalBoldForegroundColor");
    I->m_TerminalBackgroundColor =
        ExtractColor("terminalBackgroundColor");
    I->m_TerminalSelectionColor =
        ExtractColor("terminalSelectionColor");
    I->m_TerminalCursorColor =
        ExtractColor("terminalCursorColor");
    I->m_TerminalAnsiColor0 =
        ExtractColor("terminalAnsiColor0");
    I->m_TerminalAnsiColor1 =
        ExtractColor("terminalAnsiColor1");
    I->m_TerminalAnsiColor2 =
        ExtractColor("terminalAnsiColor2");
    I->m_TerminalAnsiColor3 =
        ExtractColor("terminalAnsiColor3");
    I->m_TerminalAnsiColor4 =
        ExtractColor("terminalAnsiColor4");
    I->m_TerminalAnsiColor5 =
        ExtractColor("terminalAnsiColor5");
    I->m_TerminalAnsiColor6 =
        ExtractColor("terminalAnsiColor6");
    I->m_TerminalAnsiColor7 =
        ExtractColor("terminalAnsiColor7");
    I->m_TerminalAnsiColor8 =
        ExtractColor("terminalAnsiColor8");
    I->m_TerminalAnsiColor9 =
        ExtractColor("terminalAnsiColor9");
    I->m_TerminalAnsiColorA =
        ExtractColor("terminalAnsiColorA");
    I->m_TerminalAnsiColorB =
        ExtractColor("terminalAnsiColorB");
    I->m_TerminalAnsiColorC =
        ExtractColor("terminalAnsiColorC");
    I->m_TerminalAnsiColorD =
        ExtractColor("terminalAnsiColorD");
    I->m_TerminalAnsiColorE =
        ExtractColor("terminalAnsiColorE");
    I->m_TerminalAnsiColorF =
        ExtractColor("terminalAnsiColorF");
    
    I->m_ViewerFont =
        ExtractFont("viewerFont");
    I->m_ViewerOverlayColor =
        ExtractColor("viewerOverlayColor");
    I->m_ViewerTextColor =
        ExtractColor("viewerTextColor");
    I->m_ViewerSelectionColor =
        ExtractColor("viewerSelectionColor");
    I->m_ViewerBackgroundColor =
        ExtractColor("viewerBackgroundColor");
}

Theme::~Theme()
{
}

uint64_t Theme::Generation() const noexcept
{
    return I->m_Generation;
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

NSColor *Theme::FilePanelsListFocusedActiveRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListFocusedActiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListFocusedInactiveRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListFocusedInactiveRowBackgroundColor;
}

NSColor *Theme::FilePanelsListSelectedRowBackgroundColor() const noexcept
{
    return I->m_FilePanelsListSelectedRowBackgroundColor;
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

const vector<Theme::ColoringRule>& Theme::FilePanelsItemsColoringRules() const noexcept
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

NSColor *Theme::FilePanelsBriefFocusedActiveItemBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefFocusedActiveItemBackgroundColor;
}

NSColor *Theme::FilePanelsBriefFocusedInactiveItemBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefFocusedInactiveItemBackgroundColor;
}

NSColor *Theme::FilePanelsBriefSelectedItemBackgroundColor() const noexcept
{
    return I->m_FilePanelsBriefSelectedItemBackgroundColor;
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

NSFont  *Theme::ViewerFont() const noexcept
{
    return I->m_ViewerFont;
}

NSColor *Theme::ViewerTextColor() const noexcept
{
    return I->m_ViewerTextColor;
}

NSColor *Theme::ViewerSelectionColor() const noexcept
{
    return I->m_ViewerSelectionColor;
}

NSColor *Theme::ViewerBackgroundColor() const noexcept
{
    return I->m_ViewerBackgroundColor;
}

NSColor *Theme::TerminalOverlayColor() const noexcept
{
    return I->m_TerminalOverlayColor;
}

NSColor *Theme::ViewerOverlayColor() const noexcept
{
    return I->m_ViewerOverlayColor;
}

NSColor *Theme::FilePanelsGeneralSplitterColor() const noexcept
{
    return I->m_FilePanelsGeneralSplitterColor;
}

NSColor *Theme::FilePanelsGeneralTopSeparatorColor() const noexcept
{
    return I->m_FilePanelsGeneralTopSeparatorColor;
}

NSColor *Theme::FilePanelsBriefGridColor() const noexcept
{
    return I->m_FilePanelsBriefGridColor;
}
