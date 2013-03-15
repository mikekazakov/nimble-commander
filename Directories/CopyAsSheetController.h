//
//  CopyAsSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 23.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#import <Cocoa/Cocoa.h>

#include "Common.h"

typedef void (^CopyAsSheetCompletionHandler)(int result);

@interface CopyAsSheetController : NSWindowController
@property (strong) IBOutlet NSTextField *TextField;

- (IBAction)OnOK:(id)sender;
- (IBAction)OnCancel:(id)sender;

- (void)ShowSheet: (NSWindow *)_window initialname:(NSString*)_name handler:(CopyAsSheetCompletionHandler)_handler;

@end
