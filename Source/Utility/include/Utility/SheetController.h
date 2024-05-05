// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface SheetController : NSWindowController

- (instancetype)init; // uses class name as a NIB name
- (instancetype)initWithWindowNibPath:(NSString *)_window_nib_path owner:(id)_owner;

- (void)beginSheetForWindow:(NSWindow *)_wnd completionHandler:(void (^)(NSModalResponse returnCode))_handler;
- (void)beginSheetForWindow:(NSWindow *)_wnd;

- (void)endSheet:(NSModalResponse)returnCode;

@end
