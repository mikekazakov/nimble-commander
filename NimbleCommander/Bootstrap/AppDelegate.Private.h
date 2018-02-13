// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "AppDelegate.h"

@interface NCAppDelegate()

- (void) addMainWindow:(NCMainWindowController*) _wnd;
- (void) removeMainWindow:(NCMainWindowController*) _wnd;

@end
