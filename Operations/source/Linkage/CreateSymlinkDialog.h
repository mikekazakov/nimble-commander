#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsCreateSymlinkDialog : NSWindowController<NSTextFieldDelegate>

- (instancetype) initWithSourcePath:(const string&)_src_path andDestPath:(const string&)_link_path;

@property (readonly) const string& sourcePath;
@property (readonly) const string& linkPath;

@end
