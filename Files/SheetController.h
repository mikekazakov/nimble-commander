//
//  SheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 05/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

@interface SheetController : NSWindowController

- (void) beginSheetForWindow:(NSWindow*)_wnd
           completionHandler:(void (^)(NSModalResponse returnCode))_handler;

- (void) endSheet:(NSModalResponse)returnCode;

/**
 * subclass should return true, if sheet object should contain a strong link to itself.
 * (mostly for a sheets with now logic involved after closing)
 */
- (bool) isSelfKeeping;

@end
