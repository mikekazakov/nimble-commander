//
//  PreferencesWindowThemesTab.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 1/17/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#include <fstream>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Core/Theming/ThemePersistence.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>
#include "PreferencesWindowThemesTab.h"
#include "PreferencesWindowThemesControls.h"

enum class PreferencesWindowThemesTabItemType
{
    Color,
    Font,
    ColoringRules,
    Appearance
    // bool?
};


@interface PreferencesWindowThemesTabItemNode : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) const string &entry;
@property (nonatomic, readonly) PreferencesWindowThemesTabItemType type;

- (instancetype) initWithTitle:(NSString*)title
                      forEntry:(const string&)entry
                        ofType:(PreferencesWindowThemesTabItemType)type;

@end

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


@interface PreferencesWindowThemesTabGroupNode : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSArray *children;
- (instancetype) initWithTitle:(NSString*)title andChildren:(NSArray*)children;
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

static NSTextField *SpawnSectionTitle( NSString *_title )
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.stringValue = _title;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.font = [NSFont labelFontOfSize:13];
    return tf;
}

static NSTextField *SpawnEntryTitle( NSString *_title )
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.stringValue = _title;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.font = [NSFont labelFontOfSize:11];
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    return tf;
}




// temporary!!!
/*
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
}*/


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

@interface PreferencesWindowThemesTab ()
@property (strong) IBOutlet NSOutlineView *outlineView;

@end

@implementation PreferencesWindowThemesTab
{
    NSArray *m_Nodes;
    rapidjson::StandaloneDocument m_Doc;
    ThemesManager *m_Manager;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        m_Manager = &AppDelegate.me.themesManager;
        m_Doc.CopyFrom( *m_Manager->SelectedThemeData(), rapidjson::g_CrtAllocator );
        [self setupSettingsNodes];
    }
    
    return self;
}

- (void) setupSettingsNodes
{
    auto fp_general_nodes = @[
    SpawnAppearanceNode(@"UI Appearance", "themeAppearance"),
    SpawnColoringRulesNode(@"Filenames coloring rules", "filePanelsColoringRules_v1"),
    SpawnColorNode(@"Drop border color", "filePanelsGeneralDropBorderColor"),
    SpawnColorNode(@"Overlay color", "filePanelsGeneralOverlayColor")
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
    SpawnColorNode(@"Even row background", "filePanelsBriefRegularEvenRowBackgroundColor"),
    SpawnColorNode(@"Odd row background", "filePanelsBriefRegularOddRowBackgroundColor"),
    SpawnColorNode(@"Selected & active item background", "filePanelsBriefSelectedActiveItemBackgroundColor"),
    SpawnColorNode(@"Selected & inactive item background", "filePanelsBriefSelectedInactiveItemBackgroundColor")
    ];
    
    auto fp_list_nodes = @[
    SpawnFontNode(@"Text font", "filePanelsListFont"),
    SpawnColorNode(@"Grid color", "filePanelsListGridColor"),
    SpawnFontNode(@"Header font", "filePanelsListHeaderFont"),
    SpawnColorNode(@"Header background", "filePanelsListHeaderBackgroundColor"),
    SpawnColorNode(@"Header text color", "filePanelsListHeaderTextColor"),
    SpawnColorNode(@"Header separator", "filePanelsListHeaderSeparatorColor"),
    SpawnColorNode(@"Selected & active row background", "filePanelsListSelectedActiveRowBackgroundColor"),
    SpawnColorNode(@"Selected & inactive row background", "filePanelsListSelectedInactiveRowBackgroundColor"),
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
    SpawnColorNode(@"Foreground color", "viewerTextColor"),
    SpawnColorNode(@"Selection color", "viewerSelectionColor"),
    SpawnColorNode(@"Background color", "viewerBackgroundColor")
    ];

    auto term_nodes = @[
    SpawnFontNode(@"Text font", "terminalFont"),
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

    m_Nodes = @[fp_group,
                SpawnGroupNode(@"Viewer", viewer_nodes),
                SpawnGroupNode(@"Terminal", term_nodes)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    //self.outlineView.rowHeight = 25;
    
    
    
    [self.outlineView expandItem:nil expandChildren:YES];
}

-(NSString*)identifier
{
    return NSStringFromClass(self.class);
}

-(NSImage*)toolbarItemImage
{
    return [[NSImage alloc] initWithContentsOfFile:
     @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ProfileFontAndColor.icns"];
}

-(NSString*)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Themes",
                                      @"Preferences",
                                      "General preferences tab title");
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item
{
    if( item == nil )
        return m_Nodes.count;
    if( auto n = objc_cast<PreferencesWindowThemesTabGroupNode>(item) )
        return n.children.count;
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
    if( item == nil )
        return m_Nodes[index];
    if( auto n = objc_cast<PreferencesWindowThemesTabGroupNode>(item) )
        return n.children[index];
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return objc_cast<PreferencesWindowThemesTabGroupNode>(item) != nil;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView
              viewForTableColumn:(nullable NSTableColumn *)tableColumn
                            item:(id)item
{
    if( auto n = objc_cast<PreferencesWindowThemesTabGroupNode>(item) ) {
        if( [tableColumn.identifier isEqualToString:@"title"] )
            return SpawnSectionTitle(n.title);
        
    
        return nil;
    }
    if( auto i = objc_cast<PreferencesWindowThemesTabItemNode>(item) ) {
        if( [tableColumn.identifier isEqualToString:@"title"] )
            return SpawnEntryTitle(i.title);
    
        if( [tableColumn.identifier isEqualToString:@"value"] ) {
            if( i.type == PreferencesWindowThemesTabItemType::Color ) {
                auto v = [[PreferencesWindowThemesTabColorControl alloc] initWithFrame:NSRect{}];
                v.color = ThemePersistence::ExtractColor(self.selectedThemeFrontend,
                                                         i.entry.c_str());
                v.action = @selector(onColorChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::Font ) {
                auto v = [[PreferencesWindowThemesTabFontControl alloc] initWithFrame:NSRect{}];
                v.font = ThemePersistence::ExtractFont(self.selectedThemeFrontend,
                                                       i.entry.c_str());
                v.action = @selector(onFontChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::ColoringRules ) {
                auto v = [[PreferencesWindowThemesTabColoringRulesControl alloc]
                          initWithFrame:NSRect{}];
                v.rules = ThemePersistence::ExtractRules(self.selectedThemeFrontend,
                                                       i.entry.c_str());
                v.action = @selector(onColoringRulesChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::Appearance ) {
                auto v = [[PreferencesWindowThemesAppearanceControl alloc]
                          initWithFrame:NSRect{}];
                v.themeAppearance = ThemePersistence::ExtractAppearance(self.selectedThemeFrontend,
                                                                        i.entry.c_str());
                v.action = @selector(onAppearanceChanged:);
                v.target = self;
                return v;
            }
        }
    
    
    
    }
    

    //SpawnSectionTitle


    return nil;
}

- (void)onAppearanceChanged:(id)sender
{
    if( const auto v = objc_cast<PreferencesWindowThemesAppearanceControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeAppearance(v.themeAppearance)
                              forKey:node.entry];
    }
}

- (void)onColoringRulesChanged:(id)sender
{
    if( const auto v = objc_cast<PreferencesWindowThemesTabColoringRulesControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeRules(v.rules)
                              forKey:node.entry];
    }
}

- (void)onColorChanged:(id)sender
{
    if( const auto v = objc_cast<PreferencesWindowThemesTabColorControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeColor(v.color)
                              forKey:node.entry];
    }
}

- (void)onFontChanged:(id)sender
{
    if( const auto v = objc_cast<PreferencesWindowThemesTabFontControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeFont(v.font)
                              forKey:node.entry];
    }

}

- (const rapidjson::StandaloneDocument &) selectedThemeFrontend
{
    return m_Doc; // possibly some more logic here
}
/* also theme backend if any */

- (void) commitChangedValue:(const rapidjson::StandaloneValue&)_value forKey:(const string&)_key
{
    m_Manager->SetThemeValue(m_Manager->SelectedThemeName(),
                             _key,
                             _value);
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    if( auto i = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
        if( i.type == PreferencesWindowThemesTabItemType::ColoringRules )
            return 140;

    return 18;
}


@end
