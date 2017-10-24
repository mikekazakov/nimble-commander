//
//  PreferencesWindowHotkeysTab.m
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/FunctionKeysPass.h>
#import <3rd_Party/GTMHotKeyTextField/GTMHotKeyTextField.h>
#include "../Core/ActionsShortcutsManager.h"
#include "../States/FilePanels/ExternalToolsSupport.h"
#include "../Bootstrap/ActivationManager.h"
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
        {"panel.move_up",                       NSLocalizedString(@"File Panels ▶ Move Up", "")},
        {"panel.move_down",                     NSLocalizedString(@"File Panels ▶ Move Down", "")},
        {"panel.move_left",                     NSLocalizedString(@"File Panels ▶ Move Left", "")},
        {"panel.move_right",                    NSLocalizedString(@"File Panels ▶ Move Right", "")},
        {"panel.move_first",                    NSLocalizedString(@"File Panels ▶ Move to the First Element", "")},
        {"panel.scroll_first",                  NSLocalizedString(@"File Panels ▶ Scroll to the First Element", "")},
        {"panel.move_last",                     NSLocalizedString(@"File Panels ▶ Move to the Last Element", "")},
        {"panel.scroll_last",                   NSLocalizedString(@"File Panels ▶ Scroll to the Last Element", "")},
        {"panel.move_next_page",                NSLocalizedString(@"File Panels ▶ Move to the Next Page", "")},
        {"panel.scroll_next_page",              NSLocalizedString(@"File Panels ▶ Scroll to the Next Page", "")},
        {"panel.move_prev_page",                NSLocalizedString(@"File Panels ▶ Move to the Previous Page", "")},
        {"panel.scroll_prev_page",              NSLocalizedString(@"File Panels ▶ Scroll to the Previous Page", "")},
        {"panel.move_next_and_invert_selection",NSLocalizedString(@"File Panels ▶ Toggle Selection and Move Down", "")},
        {"panel.invert_item_selection",         NSLocalizedString(@"File Panels ▶ Toggle Selection", "")},
        {"panel.go_root",                       NSLocalizedString(@"File Panels ▶ Go to Root / Directory", "")},
        {"panel.go_home",                       NSLocalizedString(@"File Panels ▶ Go to Home ~ Directory", "")},
        {"panel.show_preview",                  NSLocalizedString(@"File Panels ▶ Show Preview", "")},
        {"panel.go_into_enclosing_folder",      NSLocalizedString(@"File Panels ▶ Go to Enclosing Folder", "")},
        {"panel.go_into_folder",                NSLocalizedString(@"File Panels ▶ Go Into Folder", "")},
        {"panel.show_previous_tab",             NSLocalizedString(@"File Panels ▶ Show Previous Tab", "")},
        {"panel.show_next_tab",                 NSLocalizedString(@"File Panels ▶ Show Next Tab", "")},
        {"panel.show_tab_no_1",                 NSLocalizedString(@"File Panels ▶ Show Tab №1", "")},
        {"panel.show_tab_no_2",                 NSLocalizedString(@"File Panels ▶ Show Tab №2", "")},
        {"panel.show_tab_no_3",                 NSLocalizedString(@"File Panels ▶ Show Tab №3", "")},
        {"panel.show_tab_no_4",                 NSLocalizedString(@"File Panels ▶ Show Tab №4", "")},
        {"panel.show_tab_no_5",                 NSLocalizedString(@"File Panels ▶ Show Tab №5", "")},
        {"panel.show_tab_no_6",                 NSLocalizedString(@"File Panels ▶ Show Tab №6", "")},
        {"panel.show_tab_no_7",                 NSLocalizedString(@"File Panels ▶ Show Tab №7", "")},
        {"panel.show_tab_no_8",                 NSLocalizedString(@"File Panels ▶ Show Tab №8", "")},
        {"panel.show_tab_no_9",                 NSLocalizedString(@"File Panels ▶ Show Tab №9", "")},
        {"panel.show_tab_no_10",                NSLocalizedString(@"File Panels ▶ Show Tab №10", "")},
    };
    
    for( auto &i: titles )
        if( i.first == _action )
            return i.second;
    
    return nil;
}

static NSString *ComposeExternalToolTitle( const ExternalTool& _et, unsigned _index)
{
    return [NSString stringWithFormat:NSLocalizedString(@"Tools ▶ %@", ""),
            (_et.m_Title.empty() ?
             [NSString stringWithFormat:NSLocalizedString(@"Tool #%u", ""), _index] :
             [NSString stringWithUTF8StdString:_et.m_Title]) ];
}

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
        m_Shortcuts.assign(begin(ActionsShortcutsManager::Instance().AllShortcuts()),
                           end(ActionsShortcutsManager::Instance().AllShortcuts()));
        
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
            if( auto menu_item_title = ComposeVerboseMenuItemTitle(menu_item) )
                tf.stringValue = menu_item_title;
            else if( auto action_title = ComposeVerboseNonMenuActionTitle(tag.first) )
                tf.stringValue = action_title;
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
