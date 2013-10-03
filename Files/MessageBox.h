//
//  MessageBox.h
//  Directories
//
//  Created by Michael G. Kazakov on 27.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^MessageBoxCompletionHandler)(int result);

@interface MessageBox : NSAlert

- (void)ShowSheetWithHandler: (NSWindow *)_for_window handler:(MessageBoxCompletionHandler)_handler;
- (void)ShowSheet: (NSWindow *)_for_window ptr:(volatile int*)_retptr;

@end


// TODO: move it to a better place
void MessageBoxRetryCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret);
void MessageBoxRetrySkipCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret);
void MessageBoxRetrySkipSkipallCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret);
void MessageBoxOverwriteAppendCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret);
void MessageBoxOverwriteOverwriteallAppendAppenallSkipSkipAllCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret);
// returns NSAlertFirstButtonReturn, NSAlertSecondButtonReturn and so on
