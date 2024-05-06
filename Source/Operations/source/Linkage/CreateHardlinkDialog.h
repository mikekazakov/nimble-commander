// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <string>

@interface NCOpsCreateHardlinkDialog : NSWindowController <NSTextFieldDelegate>

- (instancetype)initWithSourceName:(const std::string &)_src;

@property(readonly, nonatomic) const std::string &result;

@end
