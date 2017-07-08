#pragma once

#include <Cocoa/Cocoa.h>

@interface NCOpsCreateHardlinkDialog : NSWindowController

- (instancetype)initWithSourceName:(const string&)_src;

@property (readonly) const string &result;

//- (void)showSheetFor:(NSWindow *)_window
//      withSourceName:(const string&)_src
//   completionHandler:(void (^)(NSModalResponse returnCode))_handler;

@end
