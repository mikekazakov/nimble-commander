// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <string>

@interface NCOpsCreateSymlinkDialog : NSWindowController<NSTextFieldDelegate>

- (instancetype) initWithSourcePath:(const std::string&)_src_path
                        andDestPath:(const std::string&)_link_path;

@property (readonly) const std::string& sourcePath;
@property (readonly) const std::string& linkPath;

@end
