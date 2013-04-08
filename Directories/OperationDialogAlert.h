//
//  OperationDialogAlert.h
//  Directories
//
//  Created by Pavel Dogurevich on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationDialogProtocol.h"

// Alert that can be queued within Operation.
// Use ShowDialogForWindow:(NSWindow *)_window to show the alert.
@interface OperationDialogAlert : NSObject <OperationDialogProtocol>

// Implements methods from OperationDialogProtocol.

- (id)init;

- (void)SetAlertStyle:(NSAlertStyle)_style;
- (void)SetIcon:(NSImage *)_icon;
- (void)SetMessageText:(NSString *)_text;
- (void)SetInformativeText:(NSString *)_text;
// Adds a button to the alert. When clicked, it will produce the specified result.
// Use OperationDialogResult::None result value to make the button hide the alert without closing it.
- (NSButton *)AddButtonWithTitle:(NSString *)_title andResult:(int)_result;

@end
