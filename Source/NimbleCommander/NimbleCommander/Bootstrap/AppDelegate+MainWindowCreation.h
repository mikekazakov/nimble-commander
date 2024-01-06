// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "AppDelegate.h"

// this category is private to NCAppDelegate
@interface NCAppDelegate(MainWindowCreation)

// these methods don't call showWindow, it's client's responsibility.

- (NCMainWindowController*)allocateDefaultMainWindow;
- (NCMainWindowController*)allocateMainWindowRestoredManually;
- (NCMainWindowController*)allocateMainWindowRestoredBySystem;

@end
