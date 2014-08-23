//
//  PreferencesWindowExternalEditorsTab.m
//  Files
//
//  Created by Michael G. Kazakov on 07.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ExternalEditorInfo.h"
#import "PreferencesWindowExternalEditorsTabNewEditorSheet.h"
#import "PreferencesWindowExternalEditorsTab.h"

#define MyPrivateTableViewDataType @"PreferencesWindowExternalEditorsTabPrivateTableViewDataType"

@implementation PreferencesWindowExternalEditorsTab

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
    
    self.TableView.Target = self;
    self.TableView.DoubleAction = @selector(OnTableDoubleClick:);
    self.TableView.dataSource = self;
    [self.TableView registerForDraggedTypes:@[MyPrivateTableViewDataType]];
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"pref_extedit_icon"];
}
-(NSString*)toolbarItemLabel{
    return @"Editors";
}

- (NSMutableArray *) ExtEditors
{
    return ExternalEditorsList.sharedList.Editors;
}

- (void) setExtEditors:(NSMutableArray *)ExtEditors
{
    ExternalEditorsList.sharedList.Editors = ExtEditors;
}

- (IBAction)OnNewEditor:(id)sender
{
    PreferencesWindowExternalEditorsTabNewEditorSheet *sheet = [PreferencesWindowExternalEditorsTabNewEditorSheet new];
    sheet.Info = [ExternalEditorInfo new];
    [sheet beginSheetForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode == NSModalResponseOK)
            [self.ExtEditorsController addObject:sheet.Info];
    }];    
}

- (void)OnTableDoubleClick:(id)table
{
    NSInteger row = [self.TableView clickedRow];
    if(row >= [self.ExtEditorsController.arrangedObjects count])
        return;
        
    ExternalEditorInfo *item = [self.ExtEditorsController.arrangedObjects objectAtIndex:row];
    PreferencesWindowExternalEditorsTabNewEditorSheet *sheet = [PreferencesWindowExternalEditorsTabNewEditorSheet new];
    sheet.Info = [item copy];
    [sheet beginSheetForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSModalResponseOK) {
                [self.ExtEditorsController removeObjectAtArrangedObjectIndex:row];
                [self.ExtEditorsController insertObject:sheet.Info atArrangedObjectIndex:row];
            }
        }
     ];
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:@[MyPrivateTableViewDataType]
                   owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes]
            forType:MyPrivateTableViewDataType];
    return true;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)operation
{
    NSData* data = [info.draggingPasteboard dataForType:MyPrivateTableViewDataType];
    NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSInteger drag_from = inds.firstIndex;
  
    if(drag_to == drag_from || // same index, above
       drag_to == drag_from + 1) // same index, below
        return false;
    
    assert(drag_from < [self.ExtEditorsController.arrangedObjects count]);
    if(drag_from < drag_to)
        drag_to--;
    
    ExternalEditorInfo *item = [self.ExtEditorsController.arrangedObjects objectAtIndex:drag_from];
    [self.ExtEditorsController removeObject:item];
    [self.ExtEditorsController insertObject:item atArrangedObjectIndex:drag_to];
    return true;
}

@end
