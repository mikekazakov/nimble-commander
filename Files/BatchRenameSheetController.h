//
//  BatchRenameSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 16/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SheetController.h"

#import "VFS.h"

@interface BatchRenameSheetController : SheetController<NSTableViewDataSource,NSTableViewDelegate,NSTextFieldDelegate>
- (instancetype) initWithListing:(shared_ptr<const VFSListing>)_listing
                      andIndeces:(vector<unsigned>)_inds;

- (IBAction)OnCancel:(id)sender;

@property (strong) IBOutlet NSTableView *FilenamesTable;
@property (strong) IBOutlet NSTextField *FilenameMask;
- (IBAction)OnFilenameMaskChanged:(id)sender;

@end
