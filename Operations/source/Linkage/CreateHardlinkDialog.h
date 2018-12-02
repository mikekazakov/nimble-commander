// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <string>

@interface NCOpsCreateHardlinkDialog : NSWindowController<NSTextFieldDelegate>

- (instancetype)initWithSourceName:(const std::string&)_src;

@property (readonly) const std::string &result;


@end
