//
//  PreferencesWindowHotkeysTab.m
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/gtm/GTMHotKeyTextField.h"
#include <Utility/NSMenu+Hierarchical.h>
#include "PreferencesWindowHotkeysTab.h"
#include "ActionsShortcutsManager.h"

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

@interface PreferencesWindowHotkeysTab()

@property (strong) IBOutlet NSTableView *Table;
@property (strong) IBOutlet GTMHotKeyTextField *HotKeyEditFieldTempl;

- (IBAction)OnApply:(id)sender;
- (IBAction)OnDefaults:(id)sender;

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
                                     if(!ActionsShortcutsManager::Instance().ShortCutFromTag(_t.second))
                                         return true;
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
    column.width = 80;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Hotkey";
    [self.Table addTableColumn:column];
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"pref_hotkeys_icon"];
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

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    assert(row < m_Shortcuts.size());
    auto &tag = m_Shortcuts[row];
    auto sc = ActionsShortcutsManager::Instance().ShortCutFromTag(tag.second);

    NSMenuItem *menu_item = [[NSApp mainMenu] itemWithTagHierarchical:tag.second];
    
    if([tableColumn.identifier isEqualToString:@"action"])
    {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        tf.toolTip = [NSString stringWithUTF8StdString:tag.first];
        if( auto title = ComposeVerboseMenuItemTitle(menu_item) )
            tf.stringValue = title;
        else
            tf.stringValue = tf.toolTip;
        tf.bordered = false;
        tf.editable = false;
        tf.drawsBackground = false;
        return tf;
    }
    if([tableColumn.identifier isEqualToString:@"hotkey"])
    {
        GTMHotKeyTextField *tf = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self.HotKeyEditFieldTempl]];
        GTMHotKey *hk = [GTMHotKey hotKeyWithKey:sc->key modifiers:sc->modifiers];
        [(GTMHotKeyTextFieldCell*)tf.cell setObjectValue:hk];
        tf.tag = tag.second;
        
        m_EditFields.emplace_back(tf);
        return tf;
    }
    return nil;
}

- (IBAction)OnApply:(id)sender
{
    auto &am = ActionsShortcutsManager::Instance();
    for(auto ed: m_EditFields)
    {
        int tag = int(ed.tag);
        
        GTMHotKey *hk = [ed.cell objectValue];
        ActionsShortcutsManager::ShortCut sc;
        sc.FromStringAndModif(hk.key, hk.modifiers);
        
        am.SetShortCutOverride(am.ActionFromTag(tag), sc);
    }
    am.SetMenuShortCuts([NSApp mainMenu]);
}

- (IBAction)OnDefaults:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringFromTable(@"Are you sure want to reset hotkeys to defaults?",
                                                   @"Preferences",
                                                   "Message text asking if user really wants to reset hotkeys to defaults");
    alert.informativeText = NSLocalizedStringFromTable(@"This will clear any custom set hotkeys.",
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

@end
