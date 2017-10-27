// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsAlterSymlinkDialog : NSWindowController

- (instancetype)initWithSourcePath:(const string&)_src_path andLinkName:(const string&)_link_name;

@property (readonly) const string& sourcePath;

@end
