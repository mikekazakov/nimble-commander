//
//  CreateDirectorySheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "Common.h"

typedef void (^CreateDirectorySheetCompletionHandler)(int result);

@interface CreateDirectorySheetController : NSWindowController
- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;
@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSButton *CreateButton;

- (void)ShowSheet: (NSWindow *)_window handler:(CreateDirectorySheetCompletionHandler)_handler;

@end
