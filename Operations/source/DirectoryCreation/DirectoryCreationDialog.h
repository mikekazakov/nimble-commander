// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsDirectoryCreationDialog : NSWindowController<NSTextFieldDelegate>

@property (nonatomic, readonly) const string &result;
@property (nonatomic, readwrite) string suggestion;
@property (nonatomic, readwrite) function<bool(const string&)> validationCallback;

@end
