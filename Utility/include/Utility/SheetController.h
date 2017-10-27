// Copyright (C) 2014-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface SheetController : NSWindowController

- (void) beginSheetForWindow:(NSWindow*)_wnd
           completionHandler:(void (^)(NSModalResponse returnCode))_handler;
- (void) beginSheetForWindow:(NSWindow*)_wnd;

- (void) endSheet:(NSModalResponse)returnCode;

@end
