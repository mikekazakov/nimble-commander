//
//  FileSysEntryAttrSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 26.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../vfs/VFS.h"
#include "../../SheetController.h"

struct FileSysAttrAlterCommand;

@interface FileSysEntryAttrSheetController : SheetController

@property (nonatomic, readonly) shared_ptr<FileSysAttrAlterCommand> Result;

- (FileSysEntryAttrSheetController*)initWithItems:(const shared_ptr<const vector<VFSListingItem>>&)_items;




//- (void)ShowSheet: (NSWindow *)_window
//       selentries: (const PanelData*)_data
//          handler: (FileSysEntryAttrSheetCompletionHandler) handler;
//- (void)ShowSheet: (NSWindow *)_window
//             data: (const PanelData*)_data
//            index:(unsigned)_ind
//          handler: (FileSysEntryAttrSheetCompletionHandler) handler;

// it's a self-owning object, so we need a retain loop to keep it alive, otherwise ARC will kill it
//@property (strong) FileSysEntryAttrSheetController *ME;




@end

@interface FileSysEntryAttrSheetController ()

@property (strong) IBOutlet NSButton *OwnerReadCheck;
@property (strong) IBOutlet NSButton *OwnerWriteCheck;
@property (strong) IBOutlet NSButton *OwnerExecCheck;
@property (strong) IBOutlet NSButton *GroupReadCheck;
@property (strong) IBOutlet NSButton *GroupWriteCheck;
@property (strong) IBOutlet NSButton *GroupExecCheck;
@property (strong) IBOutlet NSButton *OthersReadCheck;
@property (strong) IBOutlet NSButton *OthersWriteCheck;
@property (strong) IBOutlet NSButton *OthersExecCheck;
@property (strong) IBOutlet NSButton *StickyCheck;
@property (strong) IBOutlet NSButton *NoDumpCheck;
@property (strong) IBOutlet NSButton *UserImmutableCheck;
@property (strong) IBOutlet NSButton *UserAppendCheck;
@property (strong) IBOutlet NSButton *UserCompressedCheck;
@property (strong) IBOutlet NSButton *UserTrackedCheck;
@property (strong) IBOutlet NSButton *OpaqueCheck;
@property (strong) IBOutlet NSButton *HiddenCheck;
@property (strong) IBOutlet NSButton *ArchivedCheck;
@property (strong) IBOutlet NSButton *SystemImmutableCheck;
@property (strong) IBOutlet NSButton *SystemAppendCheck;
@property (strong) IBOutlet NSButton *SetUIDCheck;
@property (strong) IBOutlet NSButton *SetGIDCheck;
@property (strong) IBOutlet NSPopUpButton *UsersPopUpButton;
@property (strong) IBOutlet NSPopUpButton *GroupsPopUpButton;

@property (strong) IBOutlet NSButton *ATimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *ATimePicker;
@property (strong) IBOutlet NSButton *MTimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *MTimePicker;
@property (strong) IBOutlet NSButton *CTimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *CTimePicker;
@property (strong) IBOutlet NSButton *BTimePickerEnabled;
@property (strong) IBOutlet NSDatePicker *BTimePicker;
@property (strong) IBOutlet NSButton *ProcessSubfoldersCheck;
@property (strong) IBOutlet NSTextField *Title;

@property (strong) IBOutlet NSStackView *StackView;
@property (strong) IBOutlet NSView *StackViewTop;
@property (strong) IBOutlet NSView *StackViewMiddle;
@property (strong) IBOutlet NSView *StackViewBottom;
@property (strong) IBOutlet NSView *StackViewFooter;

- (IBAction)OnApply:(id)sender;
- (IBAction)OnCancel:(id)sender;
//- (IBAction)OnATimeClear:(id)sender;
- (IBAction)OnATimeSet:(id)sender;
//- (IBAction)OnMTimeClear:(id)sender;
- (IBAction)OnMTimeSet:(id)sender;
//- (IBAction)OnCTimeClear:(id)sender;
- (IBAction)OnCTimeSet:(id)sender;
//- (IBAction)OnBTimeClear:(id)sender;
- (IBAction)OnBTimeSet:(id)sender;
- (IBAction)OnProcessSubfolders:(id)sender;
- (IBAction)OnFlag:(id)sender;
- (IBAction)OnUIDSel:(id)sender;
- (IBAction)OnGIDSel:(id)sender;
- (IBAction)OnTimeChange:(id)sender;

- (IBAction)OnTimePickerEnabled:(id)sender;
@end
