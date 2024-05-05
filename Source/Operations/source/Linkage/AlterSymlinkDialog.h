// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <string>

@interface NCOpsAlterSymlinkDialog : NSWindowController

- (instancetype)initWithSourcePath:(const std::string &)_src_path andLinkName:(const std::string &)_link_name;

@property(readonly, nonatomic) const std::string &sourcePath;

@end
