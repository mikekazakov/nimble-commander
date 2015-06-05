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
@property (strong) IBOutlet NSComboBox *FilenameMask;
@property (strong) IBOutlet NSComboBox *SearchForComboBox;
@property (strong) IBOutlet NSComboBox *ReplaceWithComboBox;
@property (strong) IBOutlet NSButton *SearchCaseSensitive;
@property (strong) IBOutlet NSButton *SearchOnlyOnce;
@property (strong) IBOutlet NSButton *SearchInExtension;
@property (strong) IBOutlet NSButton *SearchWithRegExp;
@property (strong) IBOutlet NSPopUpButton *CaseProcessing;
@property (strong) IBOutlet NSPopUpButton *CounterDigits;


@property (strong) IBOutlet NSButton *InsertNameRangePlaceholderButton;
@property (strong) IBOutlet NSButton *InsertPlaceholderMenuButton;
@property (strong) IBOutlet NSMenu *InsertPlaceholderMenu;

@property (nonatomic, readwrite) int CounterStartsAt;
@property (nonatomic, readwrite) int CounterStepsBy;

- (IBAction)OnFilenameMaskChanged:(id)sender;
- (IBAction)OnInsertNamePlaceholder:(id)sender;
- (IBAction)OnInsertNameRangePlaceholder:(id)sender;
- (IBAction)OnInsertCounterPlaceholder:(id)sender;
- (IBAction)OnInsertExtensionPlaceholder:(id)sender;
- (IBAction)OnInsertDatePlaceholder:(id)sender;
- (IBAction)OnInsertTimePlaceholder:(id)sender;
- (IBAction)OnInsertMenu:(id)sender;
- (IBAction)OnInsertPlaceholderFromMenu:(id)sender;

- (IBAction)OnSearchForChanged:(id)sender;
- (IBAction)OnReplaceWithChanged:(id)sender;
- (IBAction)OnSearchReplaceOptionsChanged:(id)sender;
- (IBAction)OnCaseProcessingChanged:(id)sender;
- (IBAction)OnCounterSettingsChanged:(id)sender;

- (void)FocusRenamePattern;
- (void)FocusSearchFor;
- (void)FocusReplaceWith;

@end
