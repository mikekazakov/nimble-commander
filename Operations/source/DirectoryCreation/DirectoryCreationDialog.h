#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsDirectoryCreationDialog : NSWindowController<NSTextFieldDelegate>

@property (readonly) const string &result;

@end
