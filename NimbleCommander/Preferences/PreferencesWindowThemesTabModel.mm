// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowThemesTabModel.h"

@implementation PreferencesWindowThemesTabItemNode
{
    string m_Entry;
}

@synthesize entry = m_Entry;

- (instancetype) initWithTitle:(NSString*)title
                      forEntry:(const string&)entry
                        ofType:(PreferencesWindowThemesTabItemType)type
{
    if( self = [super init] ) {
        m_Entry = entry;
        _title = title;
        _type = type;
    }
    return self;
}

@end

@implementation PreferencesWindowThemesTabGroupNode

- (instancetype) initWithTitle:(NSString*)title andChildren:(NSArray*)children
{
    if( self = [super init] ) {
        _title = title;
        _children = children;
    }
    return self;
}

@end

static PreferencesWindowThemesTabItemNode* SpawnColorNode(NSString *_description,
                                                          const string& _entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc]
            initWithTitle:_description
            forEntry:_entry
            ofType:PreferencesWindowThemesTabItemType::Color];
}

static PreferencesWindowThemesTabItemNode* SpawnFontNode(NSString *_description,
                                                          const string& _entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc]
            initWithTitle:_description
            forEntry:_entry
            ofType:PreferencesWindowThemesTabItemType::Font];
}

static PreferencesWindowThemesTabItemNode* SpawnColoringRulesNode(NSString *_description,
                                                                  const string& _entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc]
            initWithTitle:_description
            forEntry:_entry
            ofType:PreferencesWindowThemesTabItemType::ColoringRules];
}

static PreferencesWindowThemesTabItemNode* SpawnAppearanceNode(NSString *_description,
                                                               const string& _entry)
{
    return [[PreferencesWindowThemesTabItemNode alloc]
            initWithTitle:_description
            forEntry:_entry
            ofType:PreferencesWindowThemesTabItemType::Appearance];
}

static PreferencesWindowThemesTabGroupNode* SpawnGroupNode(NSString *_description,
                                                          NSArray *_children)
{
    return [[PreferencesWindowThemesTabGroupNode alloc] initWithTitle:_description
                                                          andChildren:_children];
}

NSArray* BuildThemeSettingsNodesTree()
{
    auto fp_general_nodes = @[
    SpawnColoringRulesNode(@"Filenames coloring rules", "filePanelsColoringRules_v1"),
    SpawnColorNode(@"Drop border color", "filePanelsGeneralDropBorderColor"),
    SpawnColorNode(@"Overlay color", "filePanelsGeneralOverlayColor"),
    SpawnColorNode(@"Splitter color", "filePanelsGeneralSplitterColor"),
    SpawnColorNode(@"Top separator color", "filePanelsGeneralTopSeparatorColor"),
    ];
    
    auto fp_tabs_nodes = @[
    SpawnFontNode(@"Text font", "filePanelsTabsFont"),
    SpawnColorNode(@"Text color", "filePanelsTabsTextColor"),
    SpawnColorNode(@"Selected & key window & active", "filePanelsTabsSelectedKeyWndActiveBackgroundColor"),
    SpawnColorNode(@"Selected & key window", "filePanelsTabsSelectedKeyWndInactiveBackgroundColor"),
    SpawnColorNode(@"Selected", "filePanelsTabsSelectedNotKeyWndBackgroundColor"),
    SpawnColorNode(@"Regular & key window & hover", "filePanelsTabsRegularKeyWndHoverBackgroundColor"),
    SpawnColorNode(@"Regular & key window", "filePanelsTabsRegularKeyWndRegularBackgroundColor"),
    SpawnColorNode(@"Regular", "filePanelsTabsRegularNotKeyWndBackgroundColor"),
    SpawnColorNode(@"Separator", "filePanelsTabsSeparatorColor"),
    SpawnColorNode(@"Pictogram", "filePanelsTabsPictogramColor")
    ];
    
    auto fp_header_nodes = @[
    SpawnFontNode(@"Text font", "filePanelsHeaderFont"),
    SpawnColorNode(@"Regular text color", "filePanelsHeaderTextColor"),
    SpawnColorNode(@"Active text color", "filePanelsHeaderActiveTextColor"),
    SpawnColorNode(@"Active background", "filePanelsHeaderActiveBackgroundColor"),
    SpawnColorNode(@"Inactive background", "filePanelsHeaderInactiveBackgroundColor"),
    SpawnColorNode(@"Separator", "filePanelsHeaderSeparatorColor")
    ];
    
    auto fp_footer_nodes = @[
    SpawnFontNode(@"Text font", "filePanelsFooterFont"),
    SpawnColorNode(@"Regular text color", "filePanelsFooterTextColor"),
    SpawnColorNode(@"Active text color", "filePanelsFooterActiveTextColor"),
    SpawnColorNode(@"Active background", "filePanelsFooterActiveBackgroundColor"),
    SpawnColorNode(@"Inactive background", "filePanelsFooterInactiveBackgroundColor"),
    SpawnColorNode(@"Separator", "filePanelsFooterSeparatorsColor")
    ];
    
    auto fp_brief_nodes = @[
    SpawnFontNode(@"Text font", "filePanelsBriefFont"),
    SpawnColorNode(@"Grid color", "filePanelsBriefGridColor"),
    SpawnColorNode(@"Even row background", "filePanelsBriefRegularEvenRowBackgroundColor"),
    SpawnColorNode(@"Odd row background", "filePanelsBriefRegularOddRowBackgroundColor"),
    SpawnColorNode(@"Focused item background, active", "filePanelsBriefFocusedActiveItemBackgroundColor"),
    SpawnColorNode(@"Focused item background, inactive", "filePanelsBriefFocusedInactiveItemBackgroundColor"),
    SpawnColorNode(@"Selected item background", "filePanelsBriefSelectedItemBackgroundColor")
    ];
    
    auto fp_list_nodes = @[
    SpawnFontNode(@"Text font", "filePanelsListFont"),
    SpawnColorNode(@"Grid color", "filePanelsListGridColor"),
    SpawnFontNode(@"Header font", "filePanelsListHeaderFont"),
    SpawnColorNode(@"Header background", "filePanelsListHeaderBackgroundColor"),
    SpawnColorNode(@"Header text color", "filePanelsListHeaderTextColor"),
    SpawnColorNode(@"Header separator", "filePanelsListHeaderSeparatorColor"),
    SpawnColorNode(@"Focused item background, active", "filePanelsListFocusedActiveRowBackgroundColor"),
    SpawnColorNode(@"Focused item background, inactive", "filePanelsListFocusedInactiveRowBackgroundColor"),
    SpawnColorNode(@"Selected item background", "filePanelsListSelectedItemBackgroundColor"),
    SpawnColorNode(@"Even row background", "filePanelsListRegularEvenRowBackgroundColor"),
    SpawnColorNode(@"Odd row background", "filePanelsListRegularOddRowBackgroundColor")
    ];
    
    auto fp_group = SpawnGroupNode(@"File panels", @[SpawnGroupNode(@"General", fp_general_nodes),
                                                     SpawnGroupNode(@"Tabs", fp_tabs_nodes),
                                                     SpawnGroupNode(@"Header", fp_header_nodes),
                                                     SpawnGroupNode(@"Footer", fp_footer_nodes),
                                                     SpawnGroupNode(@"Brief mode", fp_brief_nodes),
                                                     SpawnGroupNode(@"List mode", fp_list_nodes)]);

    auto viewer_nodes = @[
    SpawnFontNode(@"Text font", "viewerFont"),
    SpawnColorNode(@"Overlay color", "viewerOverlayColor"),
    SpawnColorNode(@"Foreground color", "viewerTextColor"),
    SpawnColorNode(@"Selection color", "viewerSelectionColor"),
    SpawnColorNode(@"Background color", "viewerBackgroundColor")
    ];

    auto term_nodes = @[
    SpawnFontNode(@"Text font", "terminalFont"),
    SpawnColorNode(@"Overlay color", "terminalOverlayColor"),
    SpawnColorNode(@"Foreground color", "terminalForegroundColor"),
    SpawnColorNode(@"Foreground bold color", "terminalBoldForegroundColor"),
    SpawnColorNode(@"Background", "terminalBackgroundColor"),
    SpawnColorNode(@"Selection", "terminalSelectionColor"),
    SpawnColorNode(@"Cursor color", "terminalCursorColor"),
    SpawnColorNode(@"ANSI color 0 (black)", "terminalAnsiColor0"),
    SpawnColorNode(@"ANSI color 1 (red)", "terminalAnsiColor1"),
    SpawnColorNode(@"ANSI color 2 (green)", "terminalAnsiColor2"),
    SpawnColorNode(@"ANSI color 3 (yellow)", "terminalAnsiColor3"),
    SpawnColorNode(@"ANSI color 4 (blue)", "terminalAnsiColor4"),
    SpawnColorNode(@"ANSI color 5 (magenta)", "terminalAnsiColor5"),
    SpawnColorNode(@"ANSI color 6 (cyan)", "terminalAnsiColor6"),
    SpawnColorNode(@"ANSI color 7 (white)", "terminalAnsiColor7"),
    SpawnColorNode(@"ANSI color 8 (bright black)", "terminalAnsiColor8"),
    SpawnColorNode(@"ANSI color 9 (bright red)", "terminalAnsiColor9"),
    SpawnColorNode(@"ANSI color 10 (bright green)", "terminalAnsiColorA"),
    SpawnColorNode(@"ANSI color 11 (bright yellow)", "terminalAnsiColorB"),
    SpawnColorNode(@"ANSI color 12 (bright blue)", "terminalAnsiColorC"),
    SpawnColorNode(@"ANSI color 13 (bright magenta)", "terminalAnsiColorD"),
    SpawnColorNode(@"ANSI color 14 (bright cyan)", "terminalAnsiColorE"),
    SpawnColorNode(@"ANSI color 15 (bright white)", "terminalAnsiColorF"),
    ];

    auto general_nodes = @[
        [[PreferencesWindowThemesTabItemNode alloc]
            initWithTitle:@"Theme title"
            forEntry:"themeName"
            ofType:PreferencesWindowThemesTabItemType::ThemeTitle],
        SpawnAppearanceNode(@"UI Appearance", "themeAppearance")
    ];

    return @[SpawnGroupNode(@"General", general_nodes),
             fp_group,
             SpawnGroupNode(@"Viewer", viewer_nodes),
             SpawnGroupNode(@"Terminal", term_nodes)];
}
