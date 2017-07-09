#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsCreateHardlinkDialog : NSWindowController<NSTextFieldDelegate>

- (instancetype)initWithSourceName:(const string&)_src;

@property (readonly) const string &result;


@end
