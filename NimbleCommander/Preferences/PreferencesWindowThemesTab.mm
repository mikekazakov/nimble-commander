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
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "PreferencesWindowThemesTab.h"
#include "PreferencesWindowThemesControls.h"

enum class PreferencesWindowThemesTabItemType
{
    Color,
    Font,
    ColoringRule
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

static NSColor *ExtractColor( const rapidjson::StandaloneValue &_doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSColor colorWithHexStdString:cr->value.GetString()];
}

static NSFont *ExtractFont( const rapidjson::StandaloneValue &_doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSFont fontWithStringDescription:[NSString stringWithUTF8String:cr->value.GetString()]];
}

static rapidjson::StandaloneValue EncodeColor( NSColor *_color )
{
    return rapidjson::StandaloneValue([_color toHexStdString].c_str(),
                                      rapidjson::g_CrtAllocator);
}

static rapidjson::StandaloneValue EncodeFont( NSFont *_font )
{
    return rapidjson::StandaloneValue([_font toStringDescription].UTF8String,
                                      rapidjson::g_CrtAllocator);
}

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
    NSMutableArray *m_Nodes;
    rapidjson::StandaloneDocument m_Doc;
    ThemesManager *m_Manager;
}
/*
    "filePanelsBriefFont": "@systemFont, 13",
    "filePanelsBriefRegularEvenRowBackgroundColor": "@controlAlternatingRowBackgroundColors0",
    "filePanelsBriefRegularOddRowBackgroundColor": "@controlAlternatingRowBackgroundColors1",
    "filePanelsBriefSelectedActiveItemBackgroundColor": "@blueColor",
    "filePanelsBriefSelectedInactiveItemBackgroundColor": "@darkGrayColor",
*/

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        //m_Doc = GetDocument();
        m_Manager = &AppDelegate.me.themesManager;
        m_Doc.CopyFrom( *m_Manager->SelectedThemeData(), rapidjson::g_CrtAllocator );

        auto fp_brief_nodes = @[
        SpawnFontNode(@"Text font",
            "filePanelsBriefFont"),
        SpawnColorNode(@"Even row background",
            "filePanelsBriefRegularEvenRowBackgroundColor"),
        SpawnColorNode(@"Odd row background",
            "filePanelsBriefRegularOddRowBackgroundColor"),
        SpawnColorNode(@"Selected active item background",
            "filePanelsBriefSelectedActiveItemBackgroundColor"),
        SpawnColorNode(@"Selected inactive item background",
            "filePanelsBriefSelectedInactiveItemBackgroundColor")
        ];
        auto fp_brief_group = SpawnGroupNode(@"Brief mode", fp_brief_nodes);
        
        
        auto fp_group = SpawnGroupNode(@"File panels", @[fp_brief_group]);
    
        m_Nodes = [[NSMutableArray alloc] init];
        [m_Nodes addObject:fp_group];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    //self.outlineView.rowHeight = 25;
    
    
    
    
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
                v.color = ExtractColor(self.selectedThemeFrontend, i.entry.c_str());
                v.action = @selector(onColorChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::Font ) {
                auto v = [[PreferencesWindowThemesTabFontControl alloc] initWithFrame:NSRect{}];
                v.font = ExtractFont(self.selectedThemeFrontend, i.entry.c_str());
                v.action = @selector(onFontChanged:);
                v.target = self;
                return v;
                
            
            }
        }
    
    
    
    }
    

    //SpawnSectionTitle


    return nil;
}

- (void)onColorChanged:(id)sender
{
    if( const auto v = objc_cast<PreferencesWindowThemesTabColorControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:EncodeColor(v.color)
                              forKey:node.entry];
    }
}

- (void)onFontChanged:(id)sender
{
    if( const auto v = objc_cast<PreferencesWindowThemesTabFontControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:EncodeFont(v.font)
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


@end
