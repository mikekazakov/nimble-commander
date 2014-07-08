//
//  PreferencesWindowHotkeysTab.m
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowHotkeysTab.h"
#import "ActionsShortcutsManager.h"

@implementation PreferencesWindowHotkeysTab
{
    vector<GTMHotKeyTextField *> m_EditFields;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.Table.dataSource = self;
    self.Table.delegate = self;
    
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"action"];
    column.width = 300;
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
    return [NSImage imageNamed:@"pref_term_icon"];
}
-(NSString*)toolbarItemLabel{
    return @"Hotkeys";
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return ActionsShortcutsManager::Instance().AllShortcuts().size();
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    assert(row < ActionsShortcutsManager::Instance().AllShortcuts().size());
    auto &tag = ActionsShortcutsManager::Instance().AllShortcuts()[row];
    auto sc = ActionsShortcutsManager::Instance().ShortCutFromTag(tag.second);


    
    if([tableColumn.identifier isEqualToString:@"action"])
    {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        tf.stringValue = [NSString stringWithUTF8String:tag.first.c_str()];
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
    alert.messageText = @"Are you sure want to reset hotkeys to defaults?";
    alert.informativeText = @"This will clear any custom set hotkeys.";
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn) {
        ActionsShortcutsManager::Instance().RevertToDefaults();
        ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
        [self.Table reloadData];
    }
}

@end
