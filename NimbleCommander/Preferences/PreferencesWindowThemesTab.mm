// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowThemesTab.h"
#include <Config/RapidJSON.h>
#include <fstream>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Core/Theming/ThemePersistence.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>
#include "PreferencesWindowThemesControls.h"
#include "PreferencesWindowThemesTabModel.h"
#include "PreferencesWindowThemesTabImportSheet.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

using namespace std::literals;

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

@interface PreferencesWindowThemesTab ()
@property (nonatomic) IBOutlet NSOutlineView *outlineView;
@property (nonatomic) IBOutlet NSPopUpButton *themesPopUp;
@property (nonatomic) IBOutlet NSButton *importButton;
@property (nonatomic) IBOutlet NSButton *exportButton;
@property (nonatomic) bool selectedThemeCanBeRemoved;
@property (nonatomic) bool selectedThemeCanBeReverted;
@end

@implementation PreferencesWindowThemesTab
{
    NSArray *m_Nodes;
    nc::config::Document m_Doc;
    ThemesManager *m_Manager;
    std::vector<std::string> m_ThemeNames;
    int m_SelectedTheme;
    
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        m_Manager = &NCAppDelegate.me.themesManager;
        [self loadThemesNames];
        [self loadSelectedDocument];
        
        m_Nodes = BuildThemeSettingsNodesTree();
    }
    
    return self;
}

- (void) loadThemesNames
{
    m_ThemeNames = m_Manager->ThemeNames();
    assert( !m_ThemeNames.empty() ); // there should be at least 3 default themes!
    m_SelectedTheme = 0;
    auto it = find(begin(m_ThemeNames), end(m_ThemeNames), m_Manager->SelectedThemeName());
    if( it != end(m_ThemeNames) )
        m_SelectedTheme = (int)distance( begin(m_ThemeNames), it );
}

- (void) buildThemeNamesPopup
{
    [self.themesPopUp removeAllItems];
    for( int i = 0, e = (int)m_ThemeNames.size(); i != e; ++i ) {
        auto &name = m_ThemeNames[i];
        [self.themesPopUp addItemWithTitle:[NSString stringWithUTF8StdString:name]];
        self.themesPopUp.lastItem.tag = i;
    }
    [self.themesPopUp selectItemWithTag:m_SelectedTheme];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    self.importButton.enabled = nc::bootstrap::ActivationManager::Instance().HasThemesManipulation();
    self.exportButton.enabled = nc::bootstrap::ActivationManager::Instance().HasThemesManipulation();
        
    [self buildThemeNamesPopup];
    [self.outlineView expandItem:nil expandChildren:true];
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
    if( auto n = objc_cast<PreferencesWindowThemesTabGroupNode>(item) )
        return n.children[index];
    return m_Nodes[index];
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
                auto v = [[PreferencesWindowThemesAppearanceControl alloc] initWithFrame:NSRect{}];
                v.themeAppearance = ThemePersistence::ExtractAppearance(self.selectedThemeFrontend,
                                                                        i.entry.c_str());
                v.action = @selector(onAppearanceChanged:);
                v.target = self;
                /* due to a issue with MAS review proccess the following compromise decision was
                 made: let choosing UI appearance only for *non* standard themes.
                 It (hopefuly) will reduce astonishment when user changes UI appearance of *current*
                 theme instead of choosing a needed theme instead.
                 */
                v.enabled = self.selectedThemeCanBeReverted == false;
                
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::ThemeTitle ) {
                NSTextField *v = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
                v.stringValue = [NSString stringWithUTF8String:
                    self.selectedThemeFrontend[i.entry.c_str()].GetString()];
                v.bordered = false;
                v.editable = true;
                v.enabled = self.selectedThemeCanBeRemoved;
                v.usesSingleLineMode = true;
                v.lineBreakMode = NSLineBreakByTruncatingHead;
                v.delegate = self;
                return v;
            }
        }
    }
    
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

- (const nc::config::Document &) selectedThemeFrontend
{
    return m_Doc; // possibly some more logic here
}
/* also theme backend if any */

- (void) commitChangedValue:(const nc::config::Value&)_value forKey:(const std::string&)_key
{
    // CHECKS!!!
    const auto &theme_name = m_ThemeNames[m_SelectedTheme];
    m_Manager->SetThemeValue( theme_name, _key, _value );
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    if( auto i = objc_cast<PreferencesWindowThemesTabItemNode>(item) )
        if( i.type == PreferencesWindowThemesTabItemType::ColoringRules )
            return 140;

    return 18;
}

- (IBAction)onThemesPopupChange:(id)sender
{
    int selected_ind = (int)self.themesPopUp.selectedTag;
    if( selected_ind >= 0 && selected_ind < (int)m_ThemeNames.size() )
        if( m_Manager->SelectTheme(m_ThemeNames[selected_ind]) ) {
            m_SelectedTheme = selected_ind;
            [self loadSelectedDocument];
            [self.outlineView reloadData];
        }
}

- (void) loadSelectedDocument
{
    // CHECKS!!!
    const auto &theme_name = m_ThemeNames.at(m_SelectedTheme);
    m_Doc.CopyFrom( *m_Manager->ThemeData(theme_name), nc::config::g_CrtAllocator );
    
    
    self.selectedThemeCanBeRemoved = m_Manager->CanBeRemoved(theme_name);
    self.selectedThemeCanBeReverted = m_Manager->HasDefaultSettings(theme_name);
}

- (IBAction)onRevertClicked:(id)sender
{
    const auto &theme_name = m_ThemeNames.at(m_SelectedTheme);
    if( m_Manager->DiscardThemeChanges(theme_name) ) {
        [self loadSelectedDocument];
        [self.outlineView reloadData];
    }
}

- (IBAction)onExportClicked:(id)sender
{
    const auto &theme_name = m_ThemeNames.at(m_SelectedTheme);
    if( auto v = m_Manager->ThemeData(theme_name) ) {
        rapidjson::StringBuffer buffer;
        rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
        v->Accept(writer);
        
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.nameFieldStringValue = [NSString stringWithUTF8StdString:theme_name];
        panel.allowedFileTypes = @[@"json"];
        panel.allowsOtherFileTypes = false;
        panel.directoryURL = [NSFileManager.defaultManager URLForDirectory:NSDesktopDirectory
                                                                  inDomain:NSUserDomainMask
                                                         appropriateForURL:nil
                                                                    create:false
                                                                     error:nil];
        if( [panel runModal] == NSFileHandlingPanelOKButton )
            if( panel.URL != nil ) {
                auto data = [NSData dataWithBytes:buffer.GetString()
                                           length:buffer.GetSize()];
                [data writeToURL:panel.URL atomically:true];
            }
    }
}

- (void) importThemeWithURL:(NSURL*)url
{
    if( auto d = [NSData dataWithContentsOfURL:url] ) {
        std::string str { (const char*)d.bytes, d.length };
        
        auto doc = std::make_shared<rapidjson::Document>();
        rapidjson::ParseResult ok = doc->Parse<rapidjson::kParseCommentsFlag>( str.c_str() );
        if( !ok )
            return;
        
        PreferencesWindowThemesTabImportSheet *sheet =
            [[PreferencesWindowThemesTabImportSheet alloc] init];
        sheet.importAsName = url.lastPathComponent.stringByDeletingPathExtension;
        
        [sheet beginSheetForWindow:self.view.window
                 completionHandler:^(NSModalResponse returnCode) {
                     if( returnCode != NSModalResponseOK  )
                         return;
                     
                     auto name = sheet.overwriteCurrentTheme ?
                        m_ThemeNames[m_SelectedTheme] :
                        sheet.importAsName.UTF8String ;
                     
                     nc::config::Document sdoc;
                     sdoc.CopyFrom(*doc, nc::config::g_CrtAllocator);
                     bool result = sheet.overwriteCurrentTheme ?
                        m_Manager->ImportThemeData( name, sdoc ) :
                        m_Manager->AddTheme(name, sdoc);
                     
                     if( result )
                         [self reloadAll];
                 }];
    }
}

- (IBAction)onImportClicked:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"json"];
    panel.allowsOtherFileTypes = false;
    if( [panel runModal] == NSFileHandlingPanelOKButton && panel.URL != nil) {
        NSURL *url = panel.URL;
        dispatch_to_main_queue_after(200ms, [=]{
            [self importThemeWithURL:url];
        });
    }
}

- (IBAction)onDuplicateClicked:(id)sender
{
    const auto theme_name = m_ThemeNames.at(m_SelectedTheme);
    const auto new_name = m_Manager->SuitableNameForNewTheme(theme_name);
    if( m_Manager->AddTheme(new_name, self.selectedThemeFrontend) ) {
        m_Manager->SelectTheme(new_name);
        [self reloadAll];
    }
}

- (void) reloadAll
{
    [self loadThemesNames];
    [self loadSelectedDocument];
    [self buildThemeNamesPopup];
    [self.outlineView reloadData];
}

- (IBAction)onRemoveClicked:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to remove this theme?",
        "Asking user for confirmation on erasing custom theme - message");
    alert.informativeText = NSLocalizedString(@"You can’t undo this action.",
        "Asking user for confirmation on erasing custom theme - informative text");
    [alert addButtonWithTitle:NSLocalizedString(@"Yes", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    if( [alert runModal] == NSAlertFirstButtonReturn ) {
        const auto theme_name = m_ThemeNames.at(m_SelectedTheme);
        if( m_Manager->RemoveTheme(theme_name) )
            [self reloadAll];
    }
}

- (void) controlTextDidEndEditing:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;
    
    const auto row = [self.outlineView rowForView:tf];
    const id item = [self.outlineView itemAtRow:row];
    if( const auto node = objc_cast<PreferencesWindowThemesTabItemNode>(item) ) {
        if( node.type == PreferencesWindowThemesTabItemType::ThemeTitle ) {
            const auto theme_name = m_ThemeNames.at(m_SelectedTheme);
            if( m_Manager->RenameTheme(theme_name, tf.stringValue.UTF8String) )
                [self reloadAll];
            else
                tf.stringValue = [NSString stringWithUTF8StdString:theme_name];
        }
    }
}

@end
