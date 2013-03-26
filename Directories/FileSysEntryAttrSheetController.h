//
//  FileSysEntryAttrSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 26.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

class PanelData;

@interface FileSysEntryAttrSheetController : NSWindowController
- (IBAction)OnCancel:(id)sender;
- (void)ShowSheet: (NSWindow *)_window entries: (const PanelData*)_data;

// it's a self-owning object, so we need a retain loop to keep it alive, otherwise ARC will kill it
@property (strong) FileSysEntryAttrSheetController *ME;
@property (strong) IBOutlet NSButton *OwnerReadCheck;
@property (strong) IBOutlet NSButton *OwnerWriteCheck;
@property (strong) IBOutlet NSButton *OwnerExecCheck;
@property (strong) IBOutlet NSButton *GroupReadCheck;
@property (strong) IBOutlet NSButton *GroupWriteCheck;
@property (strong) IBOutlet NSButton *GroupExecCheck;
@property (strong) IBOutlet NSButton *OthersReadCheck;
@property (strong) IBOutlet NSButton *OthersWriteCheck;
@property (strong) IBOutlet NSButton *OthersExecCheck;
@property (strong) IBOutlet NSButton *NoDumpCheck;
@property (strong) IBOutlet NSButton *UserImmutableCheck;
@property (strong) IBOutlet NSButton *UserAppendCheck;
@property (strong) IBOutlet NSButton *OpaqueCheck;
@property (strong) IBOutlet NSButton *HiddenCheck;
@property (strong) IBOutlet NSButton *ArchivedCheck;
@property (strong) IBOutlet NSButton *SystemImmutableCheck;
@property (strong) IBOutlet NSButton *SystemAppendCheck;
@property (strong) IBOutlet NSPopUpButton *UsersPopUpButton;
@property (strong) IBOutlet NSPopUpButton *GroupsPopUpButton;



@end
