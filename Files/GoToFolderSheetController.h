//
//  GoToFolderSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GoToFolderSheetController : NSWindowController <NSTextFieldDelegate>

- (void)showSheetWithParentWindow:(NSWindow *)_window handler:(function<int()>)_handler;

- (IBAction)OnGo:(id)sender;
- (IBAction)OnCancel:(id)sender;

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *Error;
@property (strong) IBOutlet NSButton *GoButton;

@end
