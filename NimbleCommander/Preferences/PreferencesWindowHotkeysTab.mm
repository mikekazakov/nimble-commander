//
//  PreferencesWindowHotkeysTab.m
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/FunctionKeysPass.h>
#import "../../Files/3rd_party/gtm/GTMHotKeyTextField.h"
#include "../../Files/ActionsShortcutsManager.h"
#include "../States/FilePanels/ExternalToolsSupport.h"
#include "../../Files/ActivationManager.h"
#include "PreferencesWindowHotkeysTab.h"

static NSString *ComposeVerboseMenuItemTitle(NSMenuItem *_item)
{
    if(!_item)
        return nil;

    NSString *title = _item.title;
    
    NSMenuItem *current = _item.parentItem;
    while( current ) {
        title = [NSString stringWithFormat:@"%@ ▶ %@", current.title, title];
        current = current.parentItem;
    }
    
    return title;
}

static NSString *ComposeVerboseNonMenuActionTitle(const string &_action)
{
    static const vector< pair<const char *, NSString *> > titles = {
        {"panel.move_up",                       @"File Panels ▶ Move Up"},
        {"panel.move_down",                     @"File Panels ▶ Move Down"},
        {"panel.move_left",                     @"File Panels ▶ Move Left"},
        {"panel.move_right",                    @"File Panels ▶ Move Right"},
        {"panel.move_first",                    @"File Panels ▶ Move to the First Element"},
        {"panel.move_last",                     @"File Panels ▶ Move to the Last Element"},
        {"panel.move_next_page",                @"File Panels ▶ Move to the Next Page"},
        {"panel.move_prev_page",                @"File Panels ▶ Move to the Previous Page"},
        {"panel.move_next_and_invert_selection",@"File Panels ▶ Invert Selection and Move Next"},
        {"panel.go_root",                       @"File Panels ▶ Go to Root / Directory"},
        {"panel.go_home",                       @"File Panels ▶ Go to Home ~ Directory"},
        {"panel.show_preview",                  @"File Panels ▶ Show Preview"},
    };
    
    for( auto &i: titles )
        if( i.first == _action )
            return i.second;
    
    return nil;
}

static NSString *ComposeExternalToolTitle( const ExternalTool& _et, unsigned _index)
{
    return [NSString stringWithFormat:@"Tools  ▶ %@",
            (_et.m_Title.empty() ?
             [NSString stringWithFormat:@"Tool #%u", _index] :
             [NSString stringWithUTF8StdString:_et.m_Title]) ];
}

//const ExternalTool

@interface PreferencesWindowHotkeysTab()

@property (strong) IBOutlet NSTableView *Table;
@property (strong) IBOutlet GTMHotKeyTextField *HotKeyEditFieldTempl;
@property (strong) IBOutlet NSButton *forceFnButton;

@end

@implementation PreferencesWindowHotkeysTab
{
    vector<pair<string,int>>                            m_Shortcuts;
    function<ExternalToolsStorage&()>                   m_ToolsStorage;
    ExternalToolsStorage::ObservationTicket             m_ToolsObserver;
    vector<shared_ptr<const ExternalTool>>              m_Tools;
}

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage
{
    self = [super init];
    if (self) {
        m_ToolsStorage = _tool_storage;
        m_Shortcuts = ActionsShortcutsManager::Instance().AllShortcuts();
        
        // remove shortcuts whichs are absent in main menu
        m_Shortcuts.erase(remove_if(begin(m_Shortcuts),
                                    end(m_Shortcuts),
                                    [](auto &_t) {
                                        if(_t.first.find_first_of("menu.") != 0)
                                            return false;
                                        NSMenuItem *it = [[NSApp mainMenu] itemWithTagHierarchical:_t.second];
                                        return it == nil || it.isHidden == true;
                                    }),
                          end(m_Shortcuts)
                          );
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    m_Tools = m_ToolsStorage().GetAllTools();
    
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"action"];
    column.width = 450;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Action";
    [self.Table addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"hotkey"];
    column.width = 90;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Hotkey";
    [self.Table addTableColumn:column];
    
    if( ActivationManager::Instance().Sandboxed() )
        self.forceFnButton.hidden = true;
    
    m_ToolsObserver = m_ToolsStorage().ObserveChanges([=]{
        dispatch_to_main_queue([=]{
            auto old_tools = move(m_Tools);
            m_Tools = m_ToolsStorage().GetAllTools();
            
            
            if( m_Tools.size() != old_tools.size() )
                [self.Table noteNumberOfRowsChanged];
            [self.Table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(m_Shortcuts.size(), m_Shortcuts.size()+m_Tools.size())]
                                       columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        });
    });
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"PreferencesIcons_Hotkeys"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"Hotkeys",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Shortcuts.size() + m_Tools.size();
}

- (GTMHotKeyTextField*) makeDefaultGTMHotKeyTextField
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self.HotKeyEditFieldTempl]];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if( row >= 0 && row < m_Shortcuts.size() ) {
        auto &tag = m_Shortcuts[row];
        NSMenuItem *menu_item = [[NSApp mainMenu] itemWithTagHierarchical:tag.second];
        
        if([tableColumn.identifier isEqualToString:@"action"])
        {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
            tf.toolTip = [NSString stringWithUTF8StdString:tag.first];
            if( auto title = ComposeVerboseMenuItemTitle(menu_item) )
                tf.stringValue = title;
            else if( auto title = ComposeVerboseNonMenuActionTitle(tag.first) )
                tf.stringValue = title;
            else
                tf.stringValue = tf.toolTip;
            tf.bordered = false;
            tf.editable = false;
            tf.drawsBackground = false;
            return tf;
        }
        if( [tableColumn.identifier isEqualToString:@"hotkey"] ) {
            auto sc = ActionsShortcutsManager::Instance().ShortCutFromTag(tag.second);
            auto default_sc = ActionsShortcutsManager::Instance().DefaultShortCutFromTag(tag.second);
            GTMHotKeyTextField *tf = [self makeDefaultGTMHotKeyTextField];
            tf.action = @selector(onHKChanged:);
            tf.target = self;
            ((GTMHotKeyTextFieldCell*)tf.cell).objectValue = [GTMHotKey hotKeyWithKey:sc.Key() modifiers:sc.modifiers];
            ((GTMHotKeyTextFieldCell*)tf.cell).defaultHotKey = [GTMHotKey hotKeyWithKey:default_sc.Key() modifiers:default_sc.modifiers];
            
            if( tag.first.find_first_of("panel.") == 0 )
                ((GTMHotKeyTextFieldCell*)tf.cell).strictModifierRequirement = false;
            
            tf.tag = tag.second;
            
            return tf;
        }
    }
    else if( row >= 0 && row < m_Shortcuts.size() + m_Tools.size() ) {
        auto tool_index = row - m_Shortcuts.size();
        auto &tool = m_Tools[tool_index];
        
        if([tableColumn.identifier isEqualToString:@"action"]) {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
            tf.stringValue = ComposeExternalToolTitle(*tool, (unsigned)tool_index);
            tf.bordered = false;
            tf.editable = false;
            tf.drawsBackground = false;
            return tf;
        }
        if( [tableColumn.identifier isEqualToString:@"hotkey"] ) {
            GTMHotKeyTextField *tf = [self makeDefaultGTMHotKeyTextField];
            tf.action = @selector(onToolHKChanged:);
            tf.target = self;
            tf.tag = tool_index;
            ((GTMHotKeyTextFieldCell*)tf.cell).objectValue = [GTMHotKey hotKeyWithKey:tool->m_Shorcut.Key() modifiers:tool->m_Shorcut.modifiers];
            ((GTMHotKeyTextFieldCell*)tf.cell).defaultHotKey = [GTMHotKey hotKeyWithKey:tool->m_Shorcut.Key() modifiers:tool->m_Shorcut.modifiers];
            return tf;            
        }
    }
    return nil;
}

- (ActionShortcut) shortcutFromGTMHotKey:(GTMHotKey *)_key
{
    auto key = _key.key.length > 0 ? [_key.key characterAtIndex:0] : 0;
    auto hk = ActionsShortcutsManager::ShortCut(key, _key.modifiers);
    return hk;
}

- (IBAction)onToolHKChanged:(id)sender
{
    if( auto tf = objc_cast<GTMHotKeyTextField>(sender) ) {
        if( auto gtm_hk = objc_cast<GTMHotKey>(tf.cell.objectValue) ) {
            const auto tool_index = tf.tag;
            const auto hk = [self shortcutFromGTMHotKey:gtm_hk];
            if( tool_index < m_Tools.size() ) {
                auto &tool = m_Tools[tool_index];
                if( hk != tool->m_Shorcut ) {
                    ExternalTool changed_tool = *tool;
                    changed_tool.m_Shorcut = hk;
                    m_ToolsStorage().ReplaceTool(changed_tool, tool_index);
                }
            }
        }
    }
}

- (IBAction)onHKChanged:(id)sender
{
    auto &am = ActionsShortcutsManager::Instance();
    if( auto tf = objc_cast<GTMHotKeyTextField>(sender) )
        if( auto gtm_hk = objc_cast<GTMHotKey>(tf.cell.objectValue) ) {
            auto tag = int(tf.tag);
            auto hk = [self shortcutFromGTMHotKey:gtm_hk];
            auto action = am.ActionFromTag(tag);
            if( am.SetShortCutOverride(action, hk) )
                am.SetMenuShortCuts([NSApp mainMenu]);
        }
}

- (IBAction)OnDefaults:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringFromTable(@"Are you sure you want to reset hotkeys to defaults?",
                                                   @"Preferences",
                                                   "Message text asking if user really wants to reset hotkeys to defaults");
    alert.informativeText = NSLocalizedStringFromTable(@"This will clear any custom hotkeys.",
                                                       @"Preferences",
                                                       "Informative text when user wants to reset hotkeys to defaults");
    [alert addButtonWithTitle:NSLocalizedString(@"OK","")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel","")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn) {
        ActionsShortcutsManager::Instance().RevertToDefaults();
        ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
        [self.Table reloadData];
    }
}

- (IBAction)onForceFnChanged:(id)sender
{
    if( self.forceFnButton.state == NSOnState )
        FunctionalKeysPass::Instance().Enable();
    else
        FunctionalKeysPass::Instance().Disable();
}

@end
