// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <string>
#include <functional>

@interface NCOpsDirectoryCreationDialog : NSWindowController<NSTextFieldDelegate>

@property (nonatomic, readonly) const std::string &result;
@property (nonatomic, readwrite) std::string suggestion;
@property (nonatomic, readwrite) std::function<bool(const std::string&)> validationCallback;

@end
