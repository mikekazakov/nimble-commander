#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsAlterSymlinkDialog : NSWindowController

- (instancetype)initWithSourcePath:(const string&)_src_path andLinkName:(const string&)_link_name;

@property (readonly) const string& sourcePath;

@end
