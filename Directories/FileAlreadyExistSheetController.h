//
//  FileAlreadyExistSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^FileAlreadyExistSheetCompletionHandler)(int result, bool _remember_choice);

@interface FileAlreadyExistSheetController : NSWindowController

- (void)ShowSheet: (NSWindow *)_window
         destpath: (NSString*)_path
          newsize: (unsigned long)_newsize
          newtime: (time_t) _newtime
          exisize: (unsigned long)_exisize
          exitime: (time_t) _exitime
          handler: (FileAlreadyExistSheetCompletionHandler)_handler;
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


@end
