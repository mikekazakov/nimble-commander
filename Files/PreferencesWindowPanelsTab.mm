//
//  PreferencesWindowPanelsTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowPanelsTab.h"
#import "NSUserDefaults+myColorSupport.h"
#import "ClassicPanelViewPresentation.h"
#import "ModernPanelViewPresentation.h"
#import "PreferencesWindowPanelsTabColoringFilterSheet.h"

#define MyPrivateTableViewDataTypeClassic @"PreferencesWindowPanelsTabPrivateTableViewDataTypeClassic"
#define MyPrivateTableViewDataTypeModern @"PreferencesWindowPanelsTabPrivateTableViewDataTypeModern"

@implementation PreferencesWindowPanelsTab
{
    NSFont *m_ClassicFont;
    NSFont *m_ModernFont;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    self.classicColoringRulesTable.dataSource = self;
    self.classicColoringRulesTable.delegate = self;
    [self.classicColoringRulesTable registerForDraggedTypes:@[MyPrivateTableViewDataTypeClassic]];
    self.modernColoringRulesTable.dataSource = self;
    self.modernColoringRulesTable.delegate = self;
    [self.modernColoringRulesTable registerForDraggedTypes:@[MyPrivateTableViewDataTypeModern]];
    
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    column.width = 100;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Name";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"unfocused"];
    column.width = 60;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Regular";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"focused"];
    column.width = 60;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Focused";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"filter"];
    column.width = 60;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Filter";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.classicColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    column.width = 100;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Name";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"regular"];
    column.width = 60;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Regular";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"selected"];
    column.width = 60;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Selected";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"filter"];
    column.width = 60;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"Filter";
    ((NSTableHeaderCell*)column.headerCell).alignment = NSCenterTextAlignment;
    [self.modernColoringRulesTable addTableColumn:column];
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"pref_panels_icon.png"];
}
-(NSString*)toolbarItemLabel{
    return @"Panels";
}

- (IBAction)OnSetModernFont:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_ModernFont = [defaults fontForKey:@"FilePanelsModernFont"];
    if(!m_ModernFont) m_ModernFont = [NSFont fontWithName:@"Lucida Grande" size:13];

    NSFontManager *fontManager = NSFontManager.sharedFontManager;
    fontManager.target = self;
    fontManager.action = @selector(ChangeModernFont:);
    [fontManager setSelectedFont:m_ModernFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)ChangeModernFont:(id)sender
{
    m_ModernFont = [sender convertFont:m_ModernFont];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFont:m_ModernFont forKey:@"FilePanelsModernFont"];
}

- (IBAction)OnSetClassicFont:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_ClassicFont = [defaults fontForKey:@"FilePanelsClassicFont"];
    if(!m_ClassicFont) m_ClassicFont = [NSFont fontWithName:@"Menlo Regular" size:15];

    NSFontManager *fontManager = NSFontManager.sharedFontManager;
    fontManager.target = self;
    fontManager.action = @selector(ChangeClassicFont:);
    [fontManager setSelectedFont:m_ClassicFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)ChangeClassicFont:(id)sender
{
    m_ClassicFont = [sender convertFont:m_ClassicFont];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFont:m_ClassicFont forKey:@"FilePanelsClassicFont"];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( tableView == self.classicColoringRulesTable )
        return self.classicColoringRules.count;
    if( tableView == self.modernColoringRulesTable )
        return self.modernColoringRules.count;
    return 0;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if(tableView == self.classicColoringRulesTable) {
        assert(row < self.classicColoringRules.count);
        NSDictionary *d = [self.classicColoringRules objectAtIndex:row];
        if([tableColumn.identifier isEqualToString:@"name"]) {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
            tf.stringValue = [d objectForKey:@"name"];
            tf.bordered = false;
            tf.editable = true;
            tf.drawsBackground = false;
            tf.delegate = self;
            return tf;
        }
        if([tableColumn.identifier isEqualToString:@"unfocused"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = [NSUnarchiver unarchiveObjectWithData:[d objectForKey:@"unfocused"]];
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"focused"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = [NSUnarchiver unarchiveObjectWithData:[d objectForKey:@"focused"]];
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"filter"]) {
            NSButton *bt = [[NSButton alloc] initWithFrame:NSRect()];
            bt.title = @"edit";
            bt.buttonType = NSMomentaryPushInButton;
            bt.bezelStyle = NSRoundedBezelStyle;
            ((NSButtonCell*)bt.cell).controlSize = NSMiniControlSize;
            bt.target = self;
            bt.action = @selector(classicColoringFilterClicked:);
            return bt;
        }
    }
    if(tableView == self.modernColoringRulesTable) {
        assert(row < self.modernColoringRules.count);
        NSDictionary *d = [self.modernColoringRules objectAtIndex:row];
        if([tableColumn.identifier isEqualToString:@"name"]) {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
            tf.stringValue = [d objectForKey:@"name"];
            tf.bordered = false;
            tf.editable = true;
            tf.drawsBackground = false;
            tf.delegate = self;
            return tf;
        }
        if([tableColumn.identifier isEqualToString:@"regular"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = [NSUnarchiver unarchiveObjectWithData:[d objectForKey:@"regular"]];
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"selected"]) {
            NSColorWell *cw = [[NSColorWell alloc] initWithFrame:NSRect()];
            cw.color = [NSUnarchiver unarchiveObjectWithData:[d objectForKey:@"actsel"]];
            [cw addObserver:self forKeyPath:@"color" options:0 context:NULL];
            return cw;
        }
        if([tableColumn.identifier isEqualToString:@"filter"]) {
            NSButton *bt = [[NSButton alloc] initWithFrame:NSRect()];
            bt.title = @"edit";
            bt.buttonType = NSMomentaryPushInButton;
            bt.bezelStyle = NSRoundedBezelStyle;
            ((NSButtonCell*)bt.cell).controlSize = NSMiniControlSize;
            bt.target = self;
            bt.action = @selector(modernColoringFilterClicked:);
            return bt;
        }
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if(tableView == self.classicColoringRulesTable ||
       tableView == self.modernColoringRulesTable )
        for(int i = 1; i <= 2; ++i) {
            NSView *v = [rowView viewAtColumn:i];
            NSRect rc = v.frame;
            rc.size.width = 36;
            rc.origin.x += (v.frame.size.width - rc.size.width) / 2.;
            v.frame = rc;
        }
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if(tableView == self.classicColoringRulesTable ||
       tableView == self.modernColoringRulesTable ) {
        [[rowView viewAtColumn:1] removeObserver:self forKeyPath:@"color"];
        [[rowView viewAtColumn:2] removeObserver:self forKeyPath:@"color"];
    }
}

- (NSArray*)classicColoringRules
{
    return [NSUserDefaults.standardUserDefaults objectForKey:@"FilePanelsClassicColoringRules"];
}

- (void) setClassicColoringRules:(NSArray *)classicColoringRules
{
    [NSUserDefaults.standardUserDefaults setObject:classicColoringRules forKey:@"FilePanelsClassicColoringRules"];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;
    if( [tf.superview isKindOfClass:NSTableRowView.class] ) {
        NSTableRowView *rv = (NSTableRowView *)tf.superview;
        if( [rv.superview isKindOfClass:NSTableView.class] &&
           rv.superview == self.classicColoringRulesTable ) {
            long row_no = [((NSTableView*)rv.superview) rowForView:rv];
            if( row_no >= 0 ) {
                NSMutableArray *arr = self.classicColoringRules.mutableCopy;
                auto filt = ClassicPanelViewPresentationItemsColoringFilter::Unarchive([arr objectAtIndex:row_no]);
                filt.name = tf.stringValue.UTF8String ? tf.stringValue.UTF8String : "";
                [arr replaceObjectAtIndex:row_no withObject:filt.Archive()];
                self.classicColoringRules = arr;
            }
        }
        else if([rv.superview isKindOfClass:NSTableView.class] &&
                rv.superview == self.modernColoringRulesTable ) {
            long row_no = [((NSTableView*)rv.superview) rowForView:rv];
            if( row_no >= 0 ) {
                NSMutableArray *arr = self.modernColoringRules.mutableCopy;
                auto filt = ModernPanelViewPresentationItemsColoringFilter::Unarchive([arr objectAtIndex:row_no]);
                filt.name = tf.stringValue.UTF8String ? tf.stringValue.UTF8String : "";
                [arr replaceObjectAtIndex:row_no withObject:filt.Archive()];
                self.modernColoringRules = arr;
            }
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object &&
       [object isKindOfClass:NSColorWell.class] &&
       [keyPath isEqualToString:@"color"]) {
        NSColorWell *cw = object;
        if( [cw.superview isKindOfClass:NSTableRowView.class] ) {
            NSTableRowView *rv = (NSTableRowView *)cw.superview;
            if( [rv.superview isKindOfClass:NSTableView.class] &&
               rv.superview == self.classicColoringRulesTable ) {
                long row_no = [((NSTableView*)rv.superview) rowForView:rv];
                if( row_no >= 0 ) {
                    NSMutableArray *arr = self.classicColoringRules.mutableCopy;
                    auto filt = ClassicPanelViewPresentationItemsColoringFilter::Unarchive([arr objectAtIndex:row_no]);
                    if( [rv viewAtColumn:1] == cw )
                        filt.unfocused = DoubleColor(cw.color);
                    if( [rv viewAtColumn:2] == cw )
                        filt.focused = DoubleColor(cw.color);
                    [arr replaceObjectAtIndex:row_no withObject:filt.Archive()];
                    self.classicColoringRules = arr;
                }
            }
            else if([rv.superview isKindOfClass:NSTableView.class] &&
                    rv.superview == self.modernColoringRulesTable ) {
                long row_no = [((NSTableView*)rv.superview) rowForView:rv];
                if( row_no >= 0 ) {
                    NSMutableArray *arr = self.modernColoringRules.mutableCopy;
                    auto filt = ModernPanelViewPresentationItemsColoringFilter::Unarchive([arr objectAtIndex:row_no]);
                    if( [rv viewAtColumn:1] == cw )
                        filt.regular = cw.color;
                    if( [rv viewAtColumn:2] == cw )
                        filt.actsel = cw.color;
                    [arr replaceObjectAtIndex:row_no withObject:filt.Archive()];
                    self.modernColoringRules = arr;
                }
            }
        }
    }
}

- (void) classicColoringFilterClicked:(id)sender
{
    if(sender && [sender isKindOfClass:NSButton.class]) {
        NSTableRowView *rv = (NSTableRowView *)((NSButton *)sender).superview;
        long row_no = [((NSTableView*)rv.superview) rowForView:rv];

        __block auto filt = ClassicPanelViewPresentationItemsColoringFilter::Unarchive([self.classicColoringRules objectAtIndex:row_no]);
        __block PreferencesWindowPanelsTabColoringFilterSheet *sheet;
        sheet = [[PreferencesWindowPanelsTabColoringFilterSheet alloc] initWithFilter:filt.filter];
        [sheet beginSheetForWindow:self.view.window
                 completionHandler:^(NSModalResponse returnCode) {
                     NSMutableArray *arr = self.classicColoringRules.mutableCopy;
                     filt.filter = sheet.filter;
                     [arr replaceObjectAtIndex:row_no withObject:filt.Archive()];
                     self.classicColoringRules = arr;
                     sheet = nil;
                 }];
    }
}

- (void) modernColoringFilterClicked:(id)sender
{
    if(sender && [sender isKindOfClass:NSButton.class]) {
        NSTableRowView *rv = (NSTableRowView *)((NSButton *)sender).superview;
        long row_no = [((NSTableView*)rv.superview) rowForView:rv];
        
        __block auto filt = ModernPanelViewPresentationItemsColoringFilter::Unarchive([self.modernColoringRules objectAtIndex:row_no]);
        __block PreferencesWindowPanelsTabColoringFilterSheet *sheet;
        sheet = [[PreferencesWindowPanelsTabColoringFilterSheet alloc] initWithFilter:filt.filter];
        [sheet beginSheetForWindow:self.view.window
                 completionHandler:^(NSModalResponse returnCode) {
                     NSMutableArray *arr = self.modernColoringRules.mutableCopy;
                     filt.filter = sheet.filter;
                     [arr replaceObjectAtIndex:row_no withObject:filt.Archive()];
                     self.modernColoringRules = arr;
                     sheet = nil;
                 }];
    }
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if(aTableView == self.classicColoringRulesTable ||
       aTableView == self.modernColoringRulesTable)
        return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    if(aTableView == self.classicColoringRulesTable) {
        [pboard declareTypes:@[MyPrivateTableViewDataTypeClassic] owner:self];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:MyPrivateTableViewDataTypeClassic];
        return true;
    }
    if(aTableView == self.modernColoringRulesTable) {
        [pboard declareTypes:@[MyPrivateTableViewDataTypeModern] owner:self];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:MyPrivateTableViewDataTypeModern];
        return true;
    }
    return false;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)operation
{
    if(aTableView == self.classicColoringRulesTable) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:MyPrivateTableViewDataTypeClassic]];
        NSInteger drag_from = inds.firstIndex;
    
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1) // same index, below
            return false;
    
        assert(drag_from < self.classicColoringRules.count);
        if(drag_from < drag_to)
            drag_to--;
        
        NSMutableArray *arr = self.classicColoringRules.mutableCopy;
        id item = [arr objectAtIndex:drag_from];
        [arr removeObject:item];
        [arr insertObject:item atIndex:drag_to];
        self.classicColoringRules = arr;
        [self.classicColoringRulesTable reloadData];
        return true;
    }
    else if(aTableView == self.modernColoringRulesTable) {
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard dataForType:MyPrivateTableViewDataTypeModern]];
        NSInteger drag_from = inds.firstIndex;
        
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1) // same index, below
            return false;
        
        assert(drag_from < self.modernColoringRules.count);
        if(drag_from < drag_to)
            drag_to--;
        
        NSMutableArray *arr = self.modernColoringRules.mutableCopy;
        id item = [arr objectAtIndex:drag_from];
        [arr removeObject:item];
        [arr insertObject:item atIndex:drag_to];
        self.modernColoringRules = arr;
        [self.modernColoringRulesTable reloadData];
        return true;
    }
    return false;
}

- (IBAction)OnAddNewClassicColoringRule:(id)sender
{
    ClassicPanelViewPresentationItemsColoringFilter def;
    NSMutableArray *arr = self.classicColoringRules.mutableCopy;
    [arr addObject:def.Archive()];
    self.classicColoringRules = arr;
    [self.classicColoringRulesTable reloadData];
}

- (IBAction)OnRemoveClassicColoringRule:(id)sender
{
    NSIndexSet *indeces = self.classicColoringRulesTable.selectedRowIndexes;
    if(indeces.count == 1) {
        NSMutableArray *arr = self.classicColoringRules.mutableCopy;
        [arr removeObjectAtIndex:indeces.firstIndex];
        self.classicColoringRules = arr;
        [self.classicColoringRulesTable reloadData];
    }
}

- (NSArray*)modernColoringRules
{
    return [NSUserDefaults.standardUserDefaults objectForKey:@"FilePanelsModernColoringRules"];
}

- (void) setModernColoringRules:(NSArray *)modernColoringRules
{
    [NSUserDefaults.standardUserDefaults setObject:modernColoringRules forKey:@"FilePanelsModernColoringRules"];
}

- (IBAction)OnAddNewModernColoringRule:(id)sender
{
    ModernPanelViewPresentationItemsColoringFilter def;
    NSMutableArray *arr = self.modernColoringRules.mutableCopy;
    [arr addObject:def.Archive()];
    self.modernColoringRules = arr;
    [self.modernColoringRulesTable reloadData];
}

- (IBAction)OnRemoveModernColoringRule:(id)sender
{
    NSIndexSet *indeces = self.modernColoringRulesTable.selectedRowIndexes;
    if(indeces.count == 1) {
        NSMutableArray *arr = self.modernColoringRules.mutableCopy;
        [arr removeObjectAtIndex:indeces.firstIndex];
        self.modernColoringRules = arr;
        [self.modernColoringRulesTable reloadData];
    }
}


@end
