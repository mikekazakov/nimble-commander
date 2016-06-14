//
//  PreferencesWindowHotkeysTab.m
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/gtm/GTMHotKeyTextField.h"
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/FunctionKeysPass.h>
#include "PreferencesWindowHotkeysTab.h"
#include "ActionsShortcutsManager.h"
#include "ActivationManager.h"

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
        {"panel.move_up",                       @"File Panels ▶ move up"},
        {"panel.move_down",                     @"File Panels ▶ move down"},
        {"panel.move_left",                     @"File Panels ▶ move left"},
        {"panel.move_right",                    @"File Panels ▶ move right"},
        {"panel.move_first",                    @"File Panels ▶ move to first element"},
        {"panel.move_last",                     @"File Panels ▶ move to last element"},
        {"panel.move_next_page",                @"File Panels ▶ move to next page"},
        {"panel.move_prev_page",                @"File Panels ▶ move to previous page"},
        {"panel.move_next_and_invert_selection",@"File Panels ▶ invert selection and move next"},
        {"panel.go_root",                       @"File Panels ▶ go to root / directory"},
        {"panel.go_home",                       @"File Panels ▶ go to home ~ directory"},
        {"panel.show_preview",                  @"File Panels ▶ show preview"},
    };
    
    for( auto &i: titles )
        if( i.first == _action )
            return i.second;
    
    return nil;
}

@interface PreferencesWindowHotkeysTab()

@property (strong) IBOutlet NSTableView *Table;
@property (strong) IBOutlet GTMHotKeyTextField *HotKeyEditFieldTempl;
@property (strong) IBOutlet NSButton *forceFnButton;

@end

@implementation PreferencesWindowHotkeysTab
{
    vector<GTMHotKeyTextField *> m_EditFields;
    vector<pair<string,int>>     m_Shortcuts;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
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
    self.Table.dataSource = self;
    self.Table.delegate = self;
    
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
    return m_Shortcuts.size();
}

- (GTMHotKeyTextField*) makeDefaultGTMHotKeyTextField
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self.HotKeyEditFieldTempl]];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    assert(row < m_Shortcuts.size());
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
        
        m_EditFields.emplace_back(tf);
        return tf;
    }
    return nil;
}

- (IBAction)onHKChanged:(id)sender
{
    auto &am = ActionsShortcutsManager::Instance();
    if( auto tf = objc_cast<GTMHotKeyTextField>(sender) ) {
        auto tag = int(tf.tag);
        auto gtm_hk = objc_cast<GTMHotKey>(tf.cell.objectValue);
        auto hk = ActionsShortcutsManager::ShortCut(gtm_hk.key, gtm_hk.modifiers);
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
        m_EditFields.clear();
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
