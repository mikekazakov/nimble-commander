// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowThemesTab.h"
#include "PreferencesWindowThemesControls.h"
#include "PreferencesWindowThemesTabAutomaticSwitchingSheet.h"
#include "PreferencesWindowThemesTabImportSheet.h"
#include "PreferencesWindowThemesTabModel.h"
#include <Config/RapidJSON.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Theming/ThemePersistence.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <Panel/UI/PanelViewPresentationItemsColoringFilter.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/VerticallyCenteredTextFieldCell.h>
#include <algorithm>
#include <fstream>
#include <rapidjson/error/en.h>
#include <rapidjson/memorystream.h>
#include <rapidjson/prettywriter.h>
#include <rapidjson/stringbuffer.h>

using namespace std::literals;
using nc::ThemePersistence;

static NSTableCellView *SpawnSectionTitle(NSString *_title)
{
    NSTextField *const tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.stringValue = _title;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.font = [NSFont labelFontOfSize:13];
    tf.translatesAutoresizingMaskIntoConstraints = false;
    NSTableCellView *const cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
    [cv addSubview:tf];
    [cv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[tf]-(0)-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(tf)]];
    [cv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:cv
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1.
                                                    constant:0.]];
    return cv;
}

static NSTableCellView *SpawnEntryTitle(NSString *_title)
{
    NSTextField *const tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.stringValue = _title;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.font = [NSFont labelFontOfSize:11];
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    tf.translatesAutoresizingMaskIntoConstraints = false;
    NSTableCellView *const cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
    [cv addSubview:tf];
    [cv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[tf]-(0)-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(tf)]];
    [cv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:cv
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1.
                                                    constant:0.]];
    return cv;
}

@interface PreferencesWindowThemesTab ()
@property(nonatomic) IBOutlet NSMenu *tableAdditionalMenu;
@property(nonatomic) IBOutlet NSSegmentedControl *tableButtons;
@property(nonatomic) IBOutlet NSTableView *themesTable;
@property(nonatomic) IBOutlet NSOutlineView *outlineView;
@end

@implementation PreferencesWindowThemesTab {
    NSArray *m_Nodes;
    nc::config::Document m_Doc;
    nc::ThemesManager *m_Manager;
    std::vector<std::string> m_ThemeNames;
    size_t m_SelectedTheme;
    bool m_IgnoreThemeCursorChange;
    bool m_SelectedThemeCanBeRemoved;
    bool m_SelectedThemeCanBeReverted;
}
@synthesize tableAdditionalMenu;
@synthesize tableButtons;
@synthesize themesTable;
@synthesize outlineView;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_IgnoreThemeCursorChange = false;
        m_SelectedThemeCanBeRemoved = false;
        m_SelectedThemeCanBeReverted = false;
        m_Manager = &NCAppDelegate.me.themesManager;
        [self loadThemesNames];
        [self loadSelectedDocument];

        [[clang::no_destroy]] static auto token = m_Manager->ObserveChanges(
            nc::ThemesManager::Notifications::Name, [self] { [self onThemeManagerThemeChanged]; });

        m_Nodes = BuildThemeSettingsNodesTree();
    }

    return self;
}

- (void)loadThemesNames
{
    m_ThemeNames = m_Manager->ThemeNames();
    assert(!m_ThemeNames.empty()); // there should be at least 3 default themes!
    m_SelectedTheme = 0;
    auto it = std::ranges::find(m_ThemeNames, m_Manager->SelectedThemeName());
    if( it != std::end(m_ThemeNames) )
        m_SelectedTheme = static_cast<size_t>(std::distance(std::begin(m_ThemeNames), it));
    [self.themesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:m_SelectedTheme] byExtendingSelection:false];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.themesTable.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    self.themesTable.rowHeight = 19.;
    self.themesTable.allowsMultipleSelection = false;
    self.themesTable.allowsEmptySelection = false;
    self.themesTable.allowsColumnSelection = false;

    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"Theme"];
    col.width = 140;
    col.minWidth = 140;
    col.maxWidth = 140;
    col.title = NSLocalizedString(@"Theme", "Preferences window themes list");
    col.resizingMask = NSTableColumnNoResizing;
    col.editable = false;
    [self.themesTable addTableColumn:col];

    self.outlineView.allowsMultipleSelection = false;
    self.outlineView.allowsEmptySelection = false;
    self.outlineView.allowsColumnSelection = false;
    self.outlineView.indentationPerLevel = 4.;
    col = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    col.width = 210;
    col.minWidth = 210;
    col.maxWidth = 210;
    col.resizingMask = NSTableColumnNoResizing;
    col.editable = false;
    [self.outlineView addTableColumn:col];
    self.outlineView.outlineTableColumn = col;

    [self.outlineView removeTableColumn:self.outlineView.tableColumns.firstObject]; // remove original dummy

    col = [[NSTableColumn alloc] initWithIdentifier:@"value"];
    col.width = 300;
    col.minWidth = 300;
    col.maxWidth = 300;
    col.resizingMask = NSTableColumnNoResizing;
    col.editable = false;
    [self.outlineView addTableColumn:col];

    [self reloadAll];

    [self.outlineView expandItem:nil expandChildren:true];
}

- (void)onThemeManagerThemeChanged
{
    const auto new_theme_name = m_Manager->SelectedThemeName();
    if( new_theme_name == m_ThemeNames[m_SelectedTheme] )
        return; // no so new, huh?

    auto it = std::ranges::find(m_ThemeNames, new_theme_name);
    if( it == std::end(m_ThemeNames) )
        return;
    m_SelectedTheme = static_cast<size_t>(std::distance(std::begin(m_ThemeNames), it));
    [self.themesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:m_SelectedTheme] byExtendingSelection:false];
    [self reloadSelectedTheme];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *) [[maybe_unused]] _table_view
{
    assert(_table_view == self.themesTable);
    return static_cast<NSInteger>(m_ThemeNames.size());
}

- (NSString *)visualTitleForTheme:(size_t)_theme
{
    if( _theme >= m_ThemeNames.size() )
        return nil;
    const auto &name = m_ThemeNames[_theme];
    const auto ns_name = [NSString stringWithUTF8StdString:name];
    if( const auto auto_switching = m_Manager->AutomaticSwitching(); auto_switching.enabled ) {
        const bool is_light = auto_switching.light == name;
        const bool is_dark = auto_switching.dark == name;
        if( is_light && is_dark )
            return [NSString stringWithFormat:@"%@ 🔆🌙", ns_name];
        else if( is_light )
            return [NSString stringWithFormat:@"%@ 🔆", ns_name];
        else if( is_dark )
            return [NSString stringWithFormat:@"%@ 🌙", ns_name];
        else
            return ns_name;
    }
    else {
        return ns_name;
    }
}

- (NSView *)tableView:(NSTableView *) [[maybe_unused]] _table_view
    viewForTableColumn:(NSTableColumn *) [[maybe_unused]] _table_column
                   row:(NSInteger)_row
{
    assert(_table_view == self.themesTable);
    assert(_table_column == [self.themesTable.tableColumns objectAtIndex:0]);
    if( _row >= static_cast<NSInteger>(m_ThemeNames.size()) )
        return nil;
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.cell = [[VerticallyCenteredTextFieldCell alloc] initTextCell:@""];
    tf.stringValue = [self visualTitleForTheme:_row];
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    return tf;
}

- (void)tableViewSelectionDidChange:(NSNotification *) [[maybe_unused]] _notification
{
    assert(_notification.object == self.themesTable);
    if( m_IgnoreThemeCursorChange )
        return; // pretend you don't see this nonse...
    if( self.themesTable.selectedRow < 0 )
        return;
    size_t row = static_cast<size_t>(self.themesTable.selectedRow);
    if( row >= m_ThemeNames.size() )
        return;

    m_Manager->SelectTheme(m_ThemeNames[row]);
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"preferences.toolbar.themes"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Themes", @"Preferences", "General preferences tab title");
}

- (NSInteger)outlineView:(NSOutlineView *) [[maybe_unused]] outlineView numberOfChildrenOfItem:(nullable id)item
{
    if( item == nil )
        return m_Nodes.count;
    if( auto n = nc::objc_cast<PreferencesWindowThemesTabGroupNode>(item) )
        return n.children.count;
    return 0;
}

- (id)outlineView:(NSOutlineView *) [[maybe_unused]] outlineView child:(NSInteger)index ofItem:(nullable id)item
{
    if( auto n = nc::objc_cast<PreferencesWindowThemesTabGroupNode>(item) )
        return n.children[index];
    return m_Nodes[index];
}

- (BOOL)outlineView:(NSOutlineView *) [[maybe_unused]] outlineView isItemExpandable:(id)item
{
    return nc::objc_cast<PreferencesWindowThemesTabGroupNode>(item) != nil;
}

- (nullable NSView *)outlineView:(NSOutlineView *) [[maybe_unused]] outlineView
              viewForTableColumn:(nullable NSTableColumn *)tableColumn
                            item:(id)item
{
    if( auto n = nc::objc_cast<PreferencesWindowThemesTabGroupNode>(item) ) {
        if( [tableColumn.identifier isEqualToString:@"title"] )
            return SpawnSectionTitle(n.title);

        return nil;
    }
    if( auto i = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) ) {
        if( [tableColumn.identifier isEqualToString:@"title"] )
            return SpawnEntryTitle(i.title);

        if( [tableColumn.identifier isEqualToString:@"value"] ) {
            if( i.type == PreferencesWindowThemesTabItemType::Color ) {
                auto v = [[PreferencesWindowThemesTabColorControl alloc] initWithFrame:NSRect{}];
                v.color = ThemePersistence::ExtractColor(self.selectedThemeFrontend, i.entry.c_str());
                v.action = @selector(onColorChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::Font ) {
                auto v = [[PreferencesWindowThemesTabFontControl alloc] initWithFrame:NSRect{}];
                v.font = ThemePersistence::ExtractFont(self.selectedThemeFrontend, i.entry.c_str());
                v.action = @selector(onFontChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::ColoringRules ) {
                auto v = [[PreferencesWindowThemesTabColoringRulesControl alloc] initWithFrame:NSRect{}];
                v.rules = ThemePersistence::ExtractRules(self.selectedThemeFrontend, i.entry.c_str());
                v.action = @selector(onColoringRulesChanged:);
                v.target = self;
                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::Appearance ) {
                auto v = [[PreferencesWindowThemesAppearanceControl alloc] initWithFrame:NSRect{}];
                v.themeAppearance = ThemePersistence::ExtractAppearance(self.selectedThemeFrontend, i.entry.c_str());
                v.action = @selector(onAppearanceChanged:);
                v.target = self;
                /* due to a issue with MAS review proccess the following compromise decision was
                 made: let choosing UI appearance only for *non* standard themes.
                 It (hopefuly) will reduce astonishment when user changes UI appearance of *current*
                 theme instead of choosing a needed theme instead.
                 */
                v.enabled = !m_SelectedThemeCanBeReverted;

                return v;
            }
            if( i.type == PreferencesWindowThemesTabItemType::ThemeTitle ) {
                NSTextField *v = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
                v.stringValue = [NSString stringWithUTF8String:self.selectedThemeFrontend[i.entry.c_str()].GetString()];
                v.bordered = false;
                v.editable = true;
                v.enabled = m_SelectedThemeCanBeRemoved;
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
    if( const auto v = nc::objc_cast<PreferencesWindowThemesAppearanceControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeAppearance(v.themeAppearance) forKey:node.entry];
    }
}

- (void)onColoringRulesChanged:(id)sender
{
    if( const auto v = nc::objc_cast<PreferencesWindowThemesTabColoringRulesControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeRules(v.rules) forKey:node.entry];
    }
}

- (void)onColorChanged:(id)sender
{
    if( const auto v = nc::objc_cast<PreferencesWindowThemesTabColorControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeColor(v.color) forKey:node.entry];
    }
}

- (void)onFontChanged:(id)sender
{
    if( const auto v = nc::objc_cast<PreferencesWindowThemesTabFontControl>(sender) ) {
        const auto row = [self.outlineView rowForView:v];
        const id item = [self.outlineView itemAtRow:row];
        if( const auto node = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) )
            [self commitChangedValue:ThemePersistence::EncodeFont(v.font) forKey:node.entry];
    }
}

- (const nc::config::Document &)selectedThemeFrontend
{
    return m_Doc; // possibly some more logic here
}
/* also theme backend if any */

- (void)commitChangedValue:(const nc::config::Value &)_value forKey:(const std::string &)_key
{
    // CHECKS!!!
    const auto &theme_name = m_ThemeNames[m_SelectedTheme];
    m_Manager->SetThemeValue(theme_name, _key, _value);
}

- (CGFloat)outlineView:(NSOutlineView *) [[maybe_unused]] outlineView heightOfRowByItem:(id)item
{
    if( auto i = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) )
        if( i.type == PreferencesWindowThemesTabItemType::ColoringRules )
            return 140;

    return 20.;
}

- (void)loadSelectedDocument
{
    // CHECKS!!!
    const auto &theme_name = m_ThemeNames.at(m_SelectedTheme);
    m_Doc.CopyFrom(*m_Manager->ThemeData(theme_name), nc::config::g_CrtAllocator);

    m_SelectedThemeCanBeRemoved = m_Manager->CanBeRemoved(theme_name);
    m_SelectedThemeCanBeReverted = m_Manager->HasDefaultSettings(theme_name);
    [self.tableButtons setEnabled:m_SelectedThemeCanBeRemoved forSegment:1];
}

- (IBAction)onTableButtonClicked:(id)sender
{
    const auto segment = self.tableButtons.selectedSegment;
    if( segment == 0 ) {
        const auto theme_name = m_ThemeNames.at(m_SelectedTheme);
        const auto new_name = m_Manager->SuitableNameForNewTheme(theme_name);
        if( m_Manager->AddTheme(new_name, self.selectedThemeFrontend) ) {
            [self reloadAll];
            m_Manager->SelectTheme(new_name);
        }
    }
    else if( segment == 1 ) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Are you sure you want to remove this theme?",
                                              "Asking user for confirmation on erasing custom theme - message");
        alert.informativeText = NSLocalizedString(
            @"You can’t undo this action.", "Asking user for confirmation on erasing custom theme - informative text");
        [alert addButtonWithTitle:NSLocalizedString(@"Yes", "")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
        if( [alert runModal] == NSAlertFirstButtonReturn ) {
            const auto theme_name = m_ThemeNames.at(m_SelectedTheme);
            if( m_Manager->RemoveTheme(theme_name) )
                [self reloadAll];
        }
    }
    else if( segment == 2 ) {
        [self onDisplayAdditionalMenu];
    }
}

- (void)onDisplayAdditionalMenu
{
    const auto b = self.tableButtons.bounds;
    const auto origin = NSMakePoint(b.size.width - [self.tableButtons widthForSegment:2] - 3, b.size.height + 3);
    [self.tableAdditionalMenu popUpMenuPositioningItem:nil atLocation:origin inView:self.tableButtons];
}

- (IBAction)onRevertClicked:(id) [[maybe_unused]] sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to revert the changes of this theme?",
                                          "Asking user for confirmation on reverting a standard theme - message");
    alert.informativeText =
        NSLocalizedString(@"You can’t undo this action.",
                          "Asking user for confirmation on reverting a standard theme - informative text");
    [alert addButtonWithTitle:NSLocalizedString(@"Yes", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    if( [alert runModal] == NSAlertFirstButtonReturn ) {
        const auto &theme_name = m_ThemeNames.at(m_SelectedTheme);
        if( m_Manager->DiscardThemeChanges(theme_name) ) {
            [self reloadSelectedTheme];
        }
    }
}

- (IBAction)onExportClicked:(id) [[maybe_unused]] sender
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
        if( [panel runModal] == NSModalResponseOK )
            if( panel.URL != nil ) {
                auto data = [NSData dataWithBytes:buffer.GetString() length:buffer.GetSize()];
                [data writeToURL:panel.URL atomically:true];
            }
    }
}

- (void)importThemeWithURL:(NSURL *)url
{
    if( auto d = [NSData dataWithContentsOfURL:url] ) {
        std::string str{static_cast<const char *>(d.bytes), d.length};

        auto doc = std::make_shared<rapidjson::Document>();
        rapidjson::ParseResult ok = doc->Parse<rapidjson::kParseCommentsFlag>(str.c_str());
        if( !ok )
            return;

        PreferencesWindowThemesTabImportSheet *sheet = [[PreferencesWindowThemesTabImportSheet alloc] init];
        sheet.importAsName = url.lastPathComponent.stringByDeletingPathExtension;

        [sheet beginSheetForWindow:self.view.window
                 completionHandler:^(NSModalResponse returnCode) {
                   if( returnCode != NSModalResponseOK )
                       return;

                   auto name = sheet.overwriteCurrentTheme ? self->m_ThemeNames[self->m_SelectedTheme]
                                                           : sheet.importAsName.UTF8String;

                   nc::config::Document sdoc;
                   sdoc.CopyFrom(*doc, nc::config::g_CrtAllocator);
                   bool result = sheet.overwriteCurrentTheme ? self->m_Manager->ImportThemeData(name, sdoc)
                                                             : self->m_Manager->AddTheme(name, sdoc);

                   if( result )
                       [self reloadAll];
                 }];
    }
}

- (IBAction)onImportClicked:(id) [[maybe_unused]] sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"json"];
    panel.allowsOtherFileTypes = false;
    if( [panel runModal] == NSModalResponseOK && panel.URL != nil ) {
        NSURL *url = panel.URL;
        dispatch_to_main_queue_after(200ms, [=] { [self importThemeWithURL:url]; });
    }
}

- (void)reloadAll
{
    [self loadThemesNames];
    m_IgnoreThemeCursorChange = true;
    [self.themesTable reloadData];
    [self.themesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:m_SelectedTheme] byExtendingSelection:false];
    m_IgnoreThemeCursorChange = false;
    [self reloadSelectedTheme];
}

- (void)reloadSelectedTheme
{
    [self loadSelectedDocument];
    [self.outlineView reloadData];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;

    const auto row = [self.outlineView rowForView:tf];
    const id item = [self.outlineView itemAtRow:row];
    if( const auto node = nc::objc_cast<PreferencesWindowThemesTabItemNode>(item) ) {
        if( node.type == PreferencesWindowThemesTabItemType::ThemeTitle ) {
            const auto theme_name = m_ThemeNames.at(m_SelectedTheme);
            if( m_Manager->RenameTheme(theme_name, tf.stringValue.UTF8String) )
                [self reloadAll];
            else
                tf.stringValue = [NSString stringWithUTF8StdString:theme_name];
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)_item
{
    if( _item.menu != self.tableAdditionalMenu )
        return false;
    if( _item.action == @selector(onRevertClicked:) )
        return m_SelectedThemeCanBeReverted;
    return true;
}

- (IBAction)onConfigureAutomaticSwitching:(id)sender
{

    auto current = m_Manager->AutomaticSwitching();
    auto *sheet = [[PreferencesWindowThemesTabAutomaticSwitchingSheet alloc] initWithSwitchingSettings:current
                                                                                         andThemeNames:m_ThemeNames];

    auto handler = ^(NSModalResponse _rc) {
      if( _rc != NSModalResponseOK )
          return;
      auto new_settings = sheet.settings;
      if( new_settings == current )
          return;
      self->m_Manager->SetAutomaticSwitching(new_settings);
      [self reloadAll];
    };

    [sheet beginSheetForWindow:self.view.window completionHandler:handler];
}

@end
