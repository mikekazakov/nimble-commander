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

@end
