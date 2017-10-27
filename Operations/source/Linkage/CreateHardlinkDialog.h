// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsCreateHardlinkDialog : NSWindowController<NSTextFieldDelegate>

- (instancetype)initWithSourceName:(const string&)_src;

@property (readonly) const string &result;


@end
