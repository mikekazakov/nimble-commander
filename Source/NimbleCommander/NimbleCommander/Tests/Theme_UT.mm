// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/Core/Theming/Theme.h>
#include <Config/RapidJSON.h>
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include <Panel/UI/PanelViewPresentationItemsColoringFilter.h>
#include <rapidjson/error/en.h>

#include <algorithm>

using nc::Theme;

#define PREFIX "Theme "

static std::string ReplQuotes(std::string_view src)
{
    std::string s(src);
    std::ranges::replace(s, '\'', '\"');
    return s;
}

static nc::config::Value JSONToObj(std::string_view _json)
{
    const std::string json = ReplQuotes(_json);

    if( json.empty() )
        return nc::config::Value(rapidjson::kNullType);

    rapidjson::Document doc;
    const rapidjson::ParseResult ok = doc.Parse<rapidjson::kParseCommentsFlag>(json.data(), json.length());
    if( !ok ) {
        throw std::invalid_argument{rapidjson::GetParseError_En(ok.Code())};
    }
    nc::config::Value res;
    res.CopyFrom(doc, nc::config::g_CrtAllocator);
    return res;
}

TEST_CASE(PREFIX "Constructs from JSON")
{
    const auto json = "{\
        'themeName': 'meow',\
        'filePanelsGeneralDropBorderColor': '#010101',\
        'filePanelsGeneralOverlayColor': '#010102',\
        'filePanelsGeneralSplitterColor': '#010103',\
        'filePanelsGeneralTopSeparatorColor': '#010104',\
        'filePanelsHeaderFont': '@boldSystemFont,42',\
        'filePanelsHeaderTextColor': '#010105',\
        'filePanelsHeaderActiveTextColor': '#010106',\
        'filePanelsHeaderActiveBackgroundColor': '#010107',\
        'filePanelsHeaderInactiveBackgroundColor': '#010108',\
        'filePanelsHeaderSeparatorColor': '#010109',\
        'filePanelsFooterFont': '@boldSystemFont,43',\
        'filePanelsFooterTextColor': '#01010A',\
        'filePanelsFooterActiveTextColor': '#01010B',\
        'filePanelsFooterSeparatorsColor': '#01010C',\
        'filePanelsFooterActiveBackgroundColor': '#01010D',\
        'filePanelsFooterInactiveBackgroundColor': '#01010E',\
        'filePanelsTabsFont': '@boldSystemFont,44',\
        'filePanelsTabsTextColor': '#01010F',\
        'filePanelsTabsSelectedKeyWndActiveBackgroundColor': '#010110',\
        'filePanelsTabsSelectedKeyWndInactiveBackgroundColor': '#010111',\
        'filePanelsTabsSelectedNotKeyWndBackgroundColor': '#010112',\
        'filePanelsTabsRegularKeyWndHoverBackgroundColor': '#010113',\
        'filePanelsTabsRegularKeyWndRegularBackgroundColor': '#010114',\
        'filePanelsTabsRegularNotKeyWndBackgroundColor': '#010115',\
        'filePanelsTabsSeparatorColor': '#010116',\
        'filePanelsTabsPictogramColor': '#010117',\
        'filePanelsBriefFont': '@boldSystemFont,45',\
        'filePanelsBriefGridColor': '#010118',\
        'filePanelsBriefRegularEvenRowBackgroundColor': '#010119',\
        'filePanelsBriefRegularOddRowBackgroundColor': '#01011A',\
        'filePanelsBriefFocusedActiveItemBackgroundColor': '#01011B',\
        'filePanelsBriefFocusedInactiveItemBackgroundColor': '#01011C',\
        'filePanelsBriefSelectedItemBackgroundColor': '#01011D',\
        'filePanelsListFont': '@boldSystemFont,46',\
        'filePanelsListGridColor': '#01011E',\
        'filePanelsListHeaderFont': '@boldSystemFont,47',\
        'filePanelsListHeaderBackgroundColor': '#01011F',\
        'filePanelsListHeaderTextColor': '#010120',\
        'filePanelsListHeaderSeparatorColor': '#010121',\
        'filePanelsListFocusedActiveRowBackgroundColor': '#010122',\
        'filePanelsListRegularEvenRowBackgroundColor': '#010123',\
        'filePanelsListRegularOddRowBackgroundColor': '#010124',\
        'filePanelsListSelectedItemBackgroundColor': '#010125',\
        'terminalFont': '@boldSystemFont,48',\
        'terminalOverlayColor': '#010126',\
        'terminalForegroundColor': '#010127',\
        'terminalBoldForegroundColor': '#010128',\
        'terminalBackgroundColor': '#010129',\
        'terminalSelectionColor': '#01012A',\
        'terminalCursorColor': '#01012B',\
        'terminalAnsiColor0': '#01012C',\
        'terminalAnsiColor1': '#01012D',\
        'terminalAnsiColor2': '#01012E',\
        'terminalAnsiColor3': '#01012F',\
        'terminalAnsiColor4': '#010130',\
        'terminalAnsiColor5': '#010131',\
        'terminalAnsiColor6': '#010132',\
        'terminalAnsiColor7': '#010133',\
        'terminalAnsiColor8': '#010134',\
        'terminalAnsiColor9': '#010135',\
        'terminalAnsiColorA': '#010136',\
        'terminalAnsiColorB': '#010137',\
        'terminalAnsiColorC': '#010138',\
        'terminalAnsiColorD': '#010139',\
        'terminalAnsiColorE': '#01013A',\
        'terminalAnsiColorF': '#01013B',\
        'viewerFont': '@boldSystemFont,49',\
        'viewerOverlayColor': '#01013C',\
        'viewerTextColor': '#01013D',\
        'viewerSelectionColor': '#01013E',\
        'viewerBackgroundColor': '#01013D'\
    }";
    const Theme t{JSONToObj(json), JSONToObj("{}")};
    CHECK(t.FilePanelsGeneralDropBorderColor().toHexStdString == "#010101");
    CHECK(t.FilePanelsGeneralOverlayColor().toHexStdString == "#010102");
    CHECK(t.FilePanelsGeneralSplitterColor().toHexStdString == "#010103");
    CHECK(t.FilePanelsGeneralTopSeparatorColor().toHexStdString == "#010104");
    CHECK([t.FilePanelsHeaderFont() isEqualTo:[NSFont boldSystemFontOfSize:42]]);
    CHECK(t.FilePanelsHeaderTextColor().toHexStdString == "#010105");
    CHECK(t.FilePanelsHeaderActiveTextColor().toHexStdString == "#010106");
    CHECK(t.FilePanelsHeaderActiveBackgroundColor().toHexStdString == "#010107");
    CHECK(t.FilePanelsHeaderInactiveBackgroundColor().toHexStdString == "#010108");
    CHECK(t.FilePanelsHeaderSeparatorColor().toHexStdString == "#010109");
    CHECK([t.FilePanelsFooterFont() isEqualTo:[NSFont boldSystemFontOfSize:43]]);
    CHECK(t.FilePanelsFooterTextColor().toHexStdString == "#01010A");
    CHECK(t.FilePanelsFooterActiveTextColor().toHexStdString == "#01010B");
    CHECK(t.FilePanelsFooterSeparatorsColor().toHexStdString == "#01010C");
    CHECK(t.FilePanelsFooterActiveBackgroundColor().toHexStdString == "#01010D");
    CHECK(t.FilePanelsFooterInactiveBackgroundColor().toHexStdString == "#01010E");
    CHECK([t.FilePanelsTabsFont() isEqualTo:[NSFont boldSystemFontOfSize:44]]);
    CHECK(t.FilePanelsTabsTextColor().toHexStdString == "#01010F");
    CHECK(t.FilePanelsTabsSelectedKeyWndActiveBackgroundColor().toHexStdString == "#010110");
    CHECK(t.FilePanelsTabsSelectedKeyWndInactiveBackgroundColor().toHexStdString == "#010111");
    CHECK(t.FilePanelsTabsSelectedNotKeyWndBackgroundColor().toHexStdString == "#010112");
    CHECK(t.FilePanelsTabsRegularKeyWndHoverBackgroundColor().toHexStdString == "#010113");
    CHECK(t.FilePanelsTabsRegularKeyWndRegularBackgroundColor().toHexStdString == "#010114");
    CHECK(t.FilePanelsTabsRegularNotKeyWndBackgroundColor().toHexStdString == "#010115");
    CHECK(t.FilePanelsTabsSeparatorColor().toHexStdString == "#010116");
    CHECK(t.FilePanelsTabsPictogramColor().toHexStdString == "#010117");
    CHECK([t.FilePanelsBriefFont() isEqualTo:[NSFont boldSystemFontOfSize:45]]);
    CHECK(t.FilePanelsBriefGridColor().toHexStdString == "#010118");
    CHECK(t.FilePanelsBriefRegularEvenRowBackgroundColor().toHexStdString == "#010119");
    CHECK(t.FilePanelsBriefRegularOddRowBackgroundColor().toHexStdString == "#01011A");
    CHECK(t.FilePanelsBriefFocusedActiveItemBackgroundColor().toHexStdString == "#01011B");
    CHECK(t.FilePanelsBriefFocusedInactiveItemBackgroundColor().toHexStdString == "#01011C");
    CHECK(t.FilePanelsBriefSelectedItemBackgroundColor().toHexStdString == "#01011D");
    CHECK([t.FilePanelsListFont() isEqualTo:[NSFont boldSystemFontOfSize:46]]);
    CHECK(t.FilePanelsListGridColor().toHexStdString == "#01011E");
    CHECK([t.FilePanelsListHeaderFont() isEqualTo:[NSFont boldSystemFontOfSize:47]]);
    CHECK(t.FilePanelsListHeaderBackgroundColor().toHexStdString == "#01011F");
    CHECK(t.FilePanelsListHeaderTextColor().toHexStdString == "#010120");
    CHECK(t.FilePanelsListHeaderSeparatorColor().toHexStdString == "#010121");
    CHECK(t.FilePanelsListFocusedActiveRowBackgroundColor().toHexStdString == "#010122");
    CHECK(t.FilePanelsListRegularEvenRowBackgroundColor().toHexStdString == "#010123");
    CHECK(t.FilePanelsListRegularOddRowBackgroundColor().toHexStdString == "#010124");
    CHECK(t.FilePanelsListSelectedRowBackgroundColor().toHexStdString == "#010125");
    CHECK([t.TerminalFont() isEqualTo:[NSFont boldSystemFontOfSize:48]]);
    CHECK(t.TerminalOverlayColor().toHexStdString == "#010126");
    CHECK(t.TerminalForegroundColor().toHexStdString == "#010127");
    CHECK(t.TerminalBoldForegroundColor().toHexStdString == "#010128");
    CHECK(t.TerminalBackgroundColor().toHexStdString == "#010129");
    CHECK(t.TerminalSelectionColor().toHexStdString == "#01012A");
    CHECK(t.TerminalCursorColor().toHexStdString == "#01012B");
    CHECK(t.TerminalAnsiColor0().toHexStdString == "#01012C");
    CHECK(t.TerminalAnsiColor1().toHexStdString == "#01012D");
    CHECK(t.TerminalAnsiColor2().toHexStdString == "#01012E");
    CHECK(t.TerminalAnsiColor3().toHexStdString == "#01012F");
    CHECK(t.TerminalAnsiColor4().toHexStdString == "#010130");
    CHECK(t.TerminalAnsiColor5().toHexStdString == "#010131");
    CHECK(t.TerminalAnsiColor6().toHexStdString == "#010132");
    CHECK(t.TerminalAnsiColor7().toHexStdString == "#010133");
    CHECK(t.TerminalAnsiColor8().toHexStdString == "#010134");
    CHECK(t.TerminalAnsiColor9().toHexStdString == "#010135");
    CHECK(t.TerminalAnsiColorA().toHexStdString == "#010136");
    CHECK(t.TerminalAnsiColorB().toHexStdString == "#010137");
    CHECK(t.TerminalAnsiColorC().toHexStdString == "#010138");
    CHECK(t.TerminalAnsiColorD().toHexStdString == "#010139");
    CHECK(t.TerminalAnsiColorE().toHexStdString == "#01013A");
    CHECK(t.TerminalAnsiColorF().toHexStdString == "#01013B");
    CHECK([t.ViewerFont() isEqualTo:[NSFont boldSystemFontOfSize:49]]);
    CHECK(t.ViewerOverlayColor().toHexStdString == "#01013C");
    CHECK(t.ViewerTextColor().toHexStdString == "#01013D");
    CHECK(t.ViewerSelectionColor().toHexStdString == "#01013E");
    CHECK(t.ViewerBackgroundColor().toHexStdString == "#01013D");
    CHECK(t.FilePanelsItemsColoringRules().size() == 1);
    CHECK(t.FilePanelsItemsColoringRules().at(0) == Theme::ColoringRule{});
}
