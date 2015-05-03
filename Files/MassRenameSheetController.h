//
//  MassRenameSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 01/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SheetController.h"
#import "VFS.h"
#import "MassRename.h"

@interface MassRenameSheetAddText : NSControl<NSTextFieldDelegate>
@property (readonly, nonatomic) const string &text;
@property (readonly, nonatomic) MassRename::ApplyTo addIn;
@property (readonly, nonatomic) MassRename::Position addWhere;
@end

@interface MassRenameSheetController : SheetController<NSTableViewDataSource,NSTableViewDelegate,NSSplitViewDelegate>

- (instancetype) initWithListing:(shared_ptr<const VFSListing>)_listing
                      andIndeces:(vector<unsigned>)_inds;


- (IBAction)OnCancel:(id)sender;

@property (strong) IBOutlet MassRenameSheetAddText *referenceAddText;
@property (strong) IBOutlet NSTableView *ActionsTable;
@property (strong) IBOutlet NSSplitView *SplitView;
@property (strong) IBOutlet NSTableView *FilenamesTable;
@property (strong) IBOutlet NSSegmentedControl *PlusMinusButtons;
@property (strong) IBOutlet NSMenu *PlusMenu;

- (IBAction)OnActonChanged:(id)sender;
- (IBAction)OnPlusMinusClicked:(id)sender;

@end
