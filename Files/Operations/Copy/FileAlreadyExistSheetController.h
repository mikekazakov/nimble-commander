//
//  FileAlreadyExistSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../OperationDialogProtocol.h"

@interface FileAlreadyExistSheetController : NSWindowController <OperationDialogProtocol>

- (id)initWithFile: (const char*)_path
    newsize: (unsigned long)_newsize
    newtime: (time_t) _newtime
    exisize: (unsigned long)_exisize
    exitime: (time_t) _exitime
   remember: (bool*)  _remb
     single: (bool) _single;

@property (strong) IBOutlet NSTextField *TargetFilename;
@property (strong) IBOutlet NSTextField *NewFileSize;
@property (strong) IBOutlet NSTextField *ExistingFileSize;
@property (strong) IBOutlet NSTextField *NewFileTime;
@property (strong) IBOutlet NSTextField *ExistingFileTime;
@property (strong) IBOutlet NSButton *RememberCheck;
@property (strong) IBOutlet NSButton *OverwriteButton;
- (IBAction)OnOverwrite:(id)sender;
- (IBAction)OnSkip:(id)sender;
- (IBAction)OnAppend:(id)sender;
- (IBAction)OnRename:(id)sender;
- (IBAction)OnCancel:(id)sender;
- (IBAction)OnHide:(id)sender;

// protocol implementation
- (void)showDialogForWindow:(NSWindow *)_parent;
- (BOOL)IsVisible;
- (void)HideDialog;
- (void)CloseDialogWithResult:(int)_result;
- (int)WaitForResult;
- (void)OnDialogEnqueued:(Operation *)_operation;
@end
