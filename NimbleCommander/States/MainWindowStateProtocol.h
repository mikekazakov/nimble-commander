// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class MainWindowController;
@class MyToolbar;

@protocol MainWindowStateProtocol <NSObject>
- (NSView*) windowContentView;
- (NSToolbar*) toolbar;

@optional
- (void)Assigned;
- (void)Resigned;
- (void)didBecomeKeyWindow;
- (void)WindowDidResize;
- (void)WindowWillClose;
- (bool)WindowShouldClose:(MainWindowController*)sender;
- (bool)needsWindowTitle;
@end
