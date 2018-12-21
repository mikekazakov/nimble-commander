// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@class NCMainWindowController;

@protocol NCMainWindowState<NSObject>

@required
- (NSView*) windowStateContentView;
- (NSToolbar*) windowStateToolbar;

@optional
- (void)windowStateDidBecomeAssigned;
- (void)windowStateDidResign;
- (void)windowStateWillClose;
- (bool)windowStateShouldClose:(NCMainWindowController*)sender;
- (bool)windowStateNeedsTitle;

@end
