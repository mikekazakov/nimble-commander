// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class MainWindowController;
@class MyToolbar;

@protocol NCMainWindowState<NSObject>

@required
- (NSView*) windowStateContentView;
- (NSToolbar*) windowStateToolbar;

@optional
- (void)windowStateDidBecomeAssigned;
- (void)windowStateDidResign;
- (void)WindowWillClose;
- (bool)WindowShouldClose:(MainWindowController*)sender;
- (bool)windowStateNeedsTitle;

@end
