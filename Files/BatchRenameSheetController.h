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

@interface BatchRenameSheetController : SheetController<NSTableViewDataSource,NSTableViewDelegate,NSTextFieldDelegate,NSComboBoxDelegate>
- (instancetype) initWithListing:(const VFSListing&)_listing
                      andIndeces:(vector<unsigned>)_inds;

- (IBAction)OnCancel:(id)sender;

@property (strong) IBOutlet NSTableView *FilenamesTable;
//@property (strong) IBOutlet NSTextField *FilenameMask;
@property (strong) IBOutlet NSComboBox *FilenameMask;
@property (strong) IBOutlet NSButton *InsertNameRangePlaceholderButton;
@property (strong) IBOutlet NSButton *InsertPlaceholderMenuButton;
@property (strong) IBOutlet NSMenu *InsertPlaceholderMenu;


- (IBAction)OnFilenameMaskChanged:(id)sender;
- (IBAction)OnInsertNamePlaceholder:(id)sender;
- (IBAction)OnInsertNameRangePlaceholder:(id)sender;
- (IBAction)OnInsertCounterPlaceholder:(id)sender;
- (IBAction)OnInsertExtensionPlaceholder:(id)sender;
- (IBAction)OnInsertDatePlaceholder:(id)sender;
- (IBAction)OnInsertTimePlaceholder:(id)sender;
- (IBAction)OnInsertMenu:(id)sender;
- (IBAction)OnInsertUppercasePlaceholder:(id)sender;
- (IBAction)OnInsertLowercasePlaceholder:(id)sender;
- (IBAction)OnInsertCapitalizePlaceholder:(id)sender;
- (IBAction)OnInsertOriginalCasePlaceholder:(id)sender;


@end
