// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/States/FilePanels/ExternalEditorInfo.h>
#include "PreferencesWindowExternalEditorsTabNewEditorSheet.h"
#include "PreferencesWindowExternalEditorsTab.h"
#include <Utility/StringExtras.h>

#define MyPrivateTableViewDataType @"PreferencesWindowExternalEditorsTabPrivateTableViewDataType"

@interface PreferencesWindowExternalEditorsTab ()

@property (nonatomic) NSMutableArray *ExtEditors;
@property (nonatomic) IBOutlet NSArrayController *ExtEditorsController;
@property (nonatomic) IBOutlet NSTableView *TableView;
@property (nonatomic) IBOutlet NSSegmentedControl *addRemove;

- (IBAction)OnNewEditor:(id)sender;

@end

static bool AskUserToDeleteEditor()
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to remove this editor?", "Asking the user for confirmation on deleting the external editor - message");
    alert.informativeText = NSLocalizedString(@"This operation is not reversible.", "Asking the user for confirmation on deleting the external editor - informative text");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [alert.buttons objectAtIndex:0].keyEquivalent = @"";
    if( [alert runModal] == NSAlertFirstButtonReturn )
        return true;
    return false;
}

@implementation PreferencesWindowExternalEditorsTab
{
    NSMutableArray *m_Editors;
}

- (id)initWithNibName:(NSString *)[[maybe_unused]]nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
    
        auto v = NCAppDelegate.me.externalEditorsStorage.AllExternalEditors();
        m_Editors = [NSMutableArray new];
        for( auto i: v ) {
            ExternalEditorInfo *ed = [ExternalEditorInfo new];
            ed.name = [NSString stringWithUTF8StdString:i->Name()];
            ed.path = [NSString stringWithUTF8StdString:i->Path()];
            ed.arguments = [NSString stringWithUTF8StdString:i->Arguments()];
            ed.mask = [NSString stringWithUTF8StdString:i->Mask()];
            ed.only_files = i->OnlyFiles();
            ed.max_size = i->MaxFileSize();
            ed.terminal = i->OpenInTerminal();
            [m_Editors addObject:ed];
        }
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.TableView.target = self;
    self.TableView.doubleAction = @selector(OnTableDoubleClick:);
    self.TableView.dataSource = self;
    [self.TableView registerForDraggedTypes:@[MyPrivateTableViewDataType]];
    [self.view layoutSubtreeIfNeeded];    
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"PreferencesIcons_ExtEditors"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"Editors",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (NSMutableArray *) ExtEditors
{
    return m_Editors;
}

- (void) setExtEditors:(NSMutableArray *)ExtEditors
{
    m_Editors = ExtEditors;
    std::vector< std::shared_ptr<ExternalEditorStartupInfo> > eds;
    for( ExternalEditorInfo *i in m_Editors )
        eds.emplace_back( [i toStartupInfo] );
    
    NCAppDelegate.me.externalEditorsStorage.SetExternalEditors( eds );
}

- (IBAction)OnNewEditor:(id)[[maybe_unused]]sender
{
    PreferencesWindowExternalEditorsTabNewEditorSheet *sheet = [PreferencesWindowExternalEditorsTabNewEditorSheet new];
    sheet.Info = [ExternalEditorInfo new];
    sheet.Info.mask = @"*";
    [sheet beginSheetForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode == NSModalResponseOK)
            [self.ExtEditorsController insertObject:sheet.Info atArrangedObjectIndex:0];
    }];    
}

- (void)OnTableDoubleClick:(id)[[maybe_unused]]table
{
    NSInteger row = [self.TableView clickedRow];
    if(row >= (int)[self.ExtEditorsController.arrangedObjects count])
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

- (NSDragOperation)tableView:(NSTableView *)[[maybe_unused]]aTableView
validateDrop:(id < NSDraggingInfo >)[[maybe_unused]]info
proposedRow:(NSInteger)[[maybe_unused]]row
proposedDropOperation:(NSTableViewDropOperation)operation
{
    return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)[[maybe_unused]]aTableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:@[MyPrivateTableViewDataType]
                   owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes]
            forType:MyPrivateTableViewDataType];
    return true;
}

- (BOOL)tableView:(NSTableView *)[[maybe_unused]]aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)[[maybe_unused]]operation
{
    NSData* data = [info.draggingPasteboard dataForType:MyPrivateTableViewDataType];
    NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSInteger drag_from = inds.firstIndex;
  
    if(drag_to == drag_from || // same index, above
       drag_to == drag_from + 1) // same index, below
        return false;
    
    assert(drag_from < (long)[self.ExtEditorsController.arrangedObjects count]);
    if(drag_from < drag_to)
        drag_to--;
    
    ExternalEditorInfo *item = [self.ExtEditorsController.arrangedObjects objectAtIndex:drag_from];
    [self.ExtEditorsController removeObject:item];
    [self.ExtEditorsController insertObject:item atArrangedObjectIndex:drag_to];
    return true;
}

- (IBAction)onPlusMinus:(id)sender
{
  const auto segment = self.addRemove.selectedSegment;
    if( segment == 0 ) {
        [self OnNewEditor:sender];
    }
    else if( segment == 1 ) {
        if( self.ExtEditorsController.canRemove )
            if( AskUserToDeleteEditor() )
                [self.ExtEditorsController remove:sender];
    }
}

@end
