// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowThemesTabModel.h"

@implementation PreferencesWindowThemesTabItemNode {
    std::string m_Entry;
}

@synthesize entry = m_Entry;
@synthesize title;
@synthesize type;

- (instancetype)initWithTitle:(NSString *)_title
                     forEntry:(const std::string &)_entry
                       ofType:(PreferencesWindowThemesTabItemType)_type
{
    self = [super init];
    if( self ) {
        m_Entry = _entry;
        title = _title;
        type = _type;
    }
    return self;
}

@end

@implementation PreferencesWindowThemesTabGroupNode
@synthesize title;
@synthesize children;

- (instancetype)initWithTitle:(NSString *)_title andChildren:(NSArray *)_children
{
    self = [super init];
    if( self ) {
        title = _title;
        children = _children;
    }
    return self;
}

@end

static PreferencesWindowThemesTabItemNode *SpawnColorNode(NSString *_description, const std::string &_entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc] initWithTitle:_description
                                                            forEntry:_entry
                                                              ofType:PreferencesWindowThemesTabItemType::Color];
}

static PreferencesWindowThemesTabItemNode *SpawnFontNode(NSString *_description, const std::string &_entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc] initWithTitle:_description
                                                            forEntry:_entry
                                                              ofType:PreferencesWindowThemesTabItemType::Font];
}

static PreferencesWindowThemesTabItemNode *SpawnIntNode(NSString *_description, const std::string &_entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc] initWithTitle:_description
                                                            forEntry:_entry
                                                              ofType:PreferencesWindowThemesTabItemType::UInt];
}

static PreferencesWindowThemesTabItemNode *SpawnColoringRulesNode(NSString *_description, const std::string &_entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc] initWithTitle:_description
                                                            forEntry:_entry
                                                              ofType:PreferencesWindowThemesTabItemType::ColoringRules];
}

static PreferencesWindowThemesTabItemNode *SpawnAppearanceNode(NSString *_description, const std::string &_entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc] initWithTitle:_description
                                                            forEntry:_entry
                                                              ofType:PreferencesWindowThemesTabItemType::Appearance];
}

static PreferencesWindowThemesTabGroupNode *SpawnGroupNode(NSString *_description, NSArray *_children)
{
    return [[PreferencesWindowThemesTabGroupNode alloc] initWithTitle:_description andChildren:_children];
}

NSArray *BuildThemeSettingsNodesTree()
{
    const auto fp_general_nodes = @[
        SpawnColoringRulesNode(
            NSLocalizedStringFromTable(@"Filenames coloring rules", @"Preferences", "Theme settings entry title"),
            "filePanelsColoringRules_v1"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Drop border color", @"Preferences", "Theme settings entry title"),
                       "filePanelsGeneralDropBorderColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Overlay color", @"Preferences", "Theme settings entry title"),
                       "filePanelsGeneralOverlayColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Splitter color", @"Preferences", "Theme settings entry title"),
                       "filePanelsGeneralSplitterColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Top separator color", @"Preferences", "Theme settings entry title"),
                       "filePanelsGeneralTopSeparatorColor"),
    ];

    const auto fp_tabs_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "filePanelsTabsFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Text color", @"Preferences", "Theme settings entry title"),
                       "filePanelsTabsTextColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Selected & key window & active", @"Preferences", "Theme settings entry title"),
            "filePanelsTabsSelectedKeyWndActiveBackgroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Selected & key window", @"Preferences", "Theme settings entry title"),
            "filePanelsTabsSelectedKeyWndInactiveBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Selected", @"Preferences", "Theme settings entry title"),
                       "filePanelsTabsSelectedNotKeyWndBackgroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Regular & key window & hover", @"Preferences", "Theme settings entry title"),
            "filePanelsTabsRegularKeyWndHoverBackgroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Regular & key window", @"Preferences", "Theme settings entry title"),
            "filePanelsTabsRegularKeyWndRegularBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Regular", @"Preferences", "Theme settings entry title"),
                       "filePanelsTabsRegularNotKeyWndBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Separator", @"Preferences", "Theme settings entry title"),
                       "filePanelsTabsSeparatorColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Pictogram", @"Preferences", "Theme settings entry title"),
                       "filePanelsTabsPictogramColor")
    ];

    const auto fp_header_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "filePanelsHeaderFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Regular text color", @"Preferences", "Theme settings entry title"),
                       "filePanelsHeaderTextColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Active text color", @"Preferences", "Theme settings entry title"),
                       "filePanelsHeaderActiveTextColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Active background", @"Preferences", "Theme settings entry title"),
                       "filePanelsHeaderActiveBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Inactive background", @"Preferences", "Theme settings entry title"),
                       "filePanelsHeaderInactiveBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Separator", @"Preferences", "Theme settings entry title"),
                       "filePanelsHeaderSeparatorColor")
    ];

    const auto fp_footer_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "filePanelsFooterFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Regular text color", @"Preferences", "Theme settings entry title"),
                       "filePanelsFooterTextColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Active text color", @"Preferences", "Theme settings entry title"),
                       "filePanelsFooterActiveTextColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Active background", @"Preferences", "Theme settings entry title"),
                       "filePanelsFooterActiveBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Inactive background", @"Preferences", "Theme settings entry title"),
                       "filePanelsFooterInactiveBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Separator", @"Preferences", "Theme settings entry title"),
                       "filePanelsFooterSeparatorsColor")
    ];

    const auto fp_brief_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "filePanelsBriefFont"),
        SpawnIntNode(NSLocalizedStringFromTable(@"Row vertical padding", @"Preferences", "Theme settings entry title"),
                     "filePanelsBriefRowVerticalPadding"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Grid color", @"Preferences", "Theme settings entry title"),
                       "filePanelsBriefGridColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Even row background", @"Preferences", "Theme settings entry title"),
                       "filePanelsBriefRegularEvenRowBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Odd row background", @"Preferences", "Theme settings entry title"),
                       "filePanelsBriefRegularOddRowBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(
                           @"Focused item background, active", @"Preferences", "Theme settings entry title"),
                       "filePanelsBriefFocusedActiveItemBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(
                           @"Focused item background, inactive", @"Preferences", "Theme settings entry title"),
                       "filePanelsBriefFocusedInactiveItemBackgroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Selected item background", @"Preferences", "Theme settings entry title"),
            "filePanelsBriefSelectedItemBackgroundColor")
    ];

    const auto fp_list_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "filePanelsListFont"),
        SpawnIntNode(NSLocalizedStringFromTable(@"Row vertical padding", @"Preferences", "Theme settings entry title"),
                     "filePanelsListRowVerticalPadding"),
        SpawnIntNode(
            NSLocalizedStringFromTable(@"Secondary text opacity (%)", @"Preferences", "Theme settings entry title"),
            "filePanelsListSecondaryColumnsOpacity"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Grid color", @"Preferences", "Theme settings entry title"),
                       "filePanelsListGridColor"),
        SpawnFontNode(NSLocalizedStringFromTable(@"Header font", @"Preferences", "Theme settings entry title"),
                      "filePanelsListHeaderFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Header background", @"Preferences", "Theme settings entry title"),
                       "filePanelsListHeaderBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Header text color", @"Preferences", "Theme settings entry title"),
                       "filePanelsListHeaderTextColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Header separator", @"Preferences", "Theme settings entry title"),
                       "filePanelsListHeaderSeparatorColor"),
        SpawnColorNode(NSLocalizedStringFromTable(
                           @"Focused item background, active", @"Preferences", "Theme settings entry title"),
                       "filePanelsListFocusedActiveRowBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(
                           @"Focused item background, inactive", @"Preferences", "Theme settings entry title"),
                       "filePanelsListFocusedInactiveRowBackgroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Selected item background", @"Preferences", "Theme settings entry title"),
            "filePanelsListSelectedItemBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Even row background", @"Preferences", "Theme settings entry title"),
                       "filePanelsListRegularEvenRowBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Odd row background", @"Preferences", "Theme settings entry title"),
                       "filePanelsListRegularOddRowBackgroundColor")
    ];

    const auto fp_gallery_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "filePanelsGalleryFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Background", @"Preferences", "Theme settings entry title"),
                       "filePanelsGalleryBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(
                           @"Focused item background, active", @"Preferences", "Theme settings entry title"),
                       "filePanelsGalleryFocusedActiveItemBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(
                           @"Focused item background, inactive", @"Preferences", "Theme settings entry title"),
                       "filePanelsGalleryFocusedInactiveItemBackgroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Selected item background", @"Preferences", "Theme settings entry title"),
            "filePanelsGallerySelectedItemBackgroundColor")
    ];

    const auto fp_group =
        SpawnGroupNode(NSLocalizedStringFromTable(@"File panels", @"Preferences", "Theme settings group title"), @[
            SpawnGroupNode(NSLocalizedStringFromTable(@"General", @"Preferences", "Theme settings group title"),
                           fp_general_nodes),
            SpawnGroupNode(NSLocalizedStringFromTable(@"Tabs", @"Preferences", "Theme settings group title"),
                           fp_tabs_nodes),
            SpawnGroupNode(NSLocalizedStringFromTable(@"Header", @"Preferences", "Theme settings group title"),
                           fp_header_nodes),
            SpawnGroupNode(NSLocalizedStringFromTable(@"Footer", @"Preferences", "Theme settings group title"),
                           fp_footer_nodes),
            SpawnGroupNode(NSLocalizedStringFromTable(@"Brief mode", @"Preferences", "Theme settings group title"),
                           fp_brief_nodes),
            SpawnGroupNode(NSLocalizedStringFromTable(@"List mode", @"Preferences", "Theme settings group title"),
                           fp_list_nodes),
            SpawnGroupNode(NSLocalizedStringFromTable(@"Gallery mode", @"Preferences", "Theme settings group title"),
                           fp_gallery_nodes)
        ]);

    const auto viewer_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "viewerFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Overlay color", @"Preferences", "Theme settings entry title"),
                       "viewerOverlayColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Foreground color", @"Preferences", "Theme settings entry title"),
                       "viewerTextColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - keyword", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxKeywordColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - operator", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxOperatorColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - identifier", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxIdentifierColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - number", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxNumberColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - string", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxStringColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - comment", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxCommentColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Syntax color - preprocessor", @"Preferences", "Theme settings entry title"),
            "viewerTextSyntaxPreprocessorColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Selection color", @"Preferences", "Theme settings entry title"),
                       "viewerSelectionColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Background color", @"Preferences", "Theme settings entry title"),
                       "viewerBackgroundColor")
    ];

    const auto term_nodes = @[
        SpawnFontNode(NSLocalizedStringFromTable(@"Text font", @"Preferences", "Theme settings entry title"),
                      "terminalFont"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Overlay color", @"Preferences", "Theme settings entry title"),
                       "terminalOverlayColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Foreground color", @"Preferences", "Theme settings entry title"),
                       "terminalForegroundColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"Foreground bold color", @"Preferences", "Theme settings entry title"),
            "terminalBoldForegroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Background", @"Preferences", "Theme settings entry title"),
                       "terminalBackgroundColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Selection", @"Preferences", "Theme settings entry title"),
                       "terminalSelectionColor"),
        SpawnColorNode(NSLocalizedStringFromTable(@"Cursor color", @"Preferences", "Theme settings entry title"),
                       "terminalCursorColor"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 0 (black)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor0"),
        SpawnColorNode(NSLocalizedStringFromTable(@"ANSI color 1 (red)", @"Preferences", "Theme settings entry title"),
                       "terminalAnsiColor1"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 2 (green)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor2"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 3 (yellow)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor3"),
        SpawnColorNode(NSLocalizedStringFromTable(@"ANSI color 4 (blue)", @"Preferences", "Theme settings entry title"),
                       "terminalAnsiColor4"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 5 (magenta)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor5"),
        SpawnColorNode(NSLocalizedStringFromTable(@"ANSI color 6 (cyan)", @"Preferences", "Theme settings entry title"),
                       "terminalAnsiColor6"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 7 (white)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor7"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 8 (bright black)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor8"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 9 (bright red)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColor9"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 10 (bright green)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColorA"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 11 (bright yellow)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColorB"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 12 (bright blue)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColorC"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 13 (bright magenta)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColorD"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 14 (bright cyan)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColorE"),
        SpawnColorNode(
            NSLocalizedStringFromTable(@"ANSI color 15 (bright white)", @"Preferences", "Theme settings entry title"),
            "terminalAnsiColorF"),
    ];

    const auto general_nodes = @[
        [[PreferencesWindowThemesTabItemNode alloc]
            initWithTitle:NSLocalizedStringFromTable(@"Theme title", @"Preferences", "Theme settings entry title")
                 forEntry:"themeName"
                   ofType:PreferencesWindowThemesTabItemType::ThemeTitle],
        SpawnAppearanceNode(NSLocalizedStringFromTable(@"UI Appearance", @"Preferences", "Theme settings entry title"),
                            "themeAppearance")
    ];

    return @[
        SpawnGroupNode(NSLocalizedStringFromTable(@"General", @"Preferences", "Theme settings group title"),
                       general_nodes),
        fp_group,
        SpawnGroupNode(NSLocalizedStringFromTable(@"Viewer", @"Preferences", "Theme settings group title"),
                       viewer_nodes),
        SpawnGroupNode(NSLocalizedStringFromTable(@"Terminal", @"Preferences", "Theme settings group title"),
                       term_nodes)
    ];
}
