//
//  MessageBox.h
//  Directories
//
//  Created by Michael G. Kazakov on 27.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MessageBox : NSAlert

- (void)beginSheetModalForWindow:(NSWindow *)_for_window completionHandler:(void (^)(NSModalResponse returnCode))_handler;

@end
