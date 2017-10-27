// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsDirectoryCreationDialog : NSWindowController<NSTextFieldDelegate>

@property (readonly) const string &result;

@end
