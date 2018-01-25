// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "AppDelegate.h"

@interface NCAppDelegate()

- (void) addMainWindow:(MainWindowController*) _wnd;
- (void) removeMainWindow:(MainWindowController*) _wnd;

@end
