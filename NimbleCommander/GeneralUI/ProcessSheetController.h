// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface ProcessSheetController : NSWindowController

- (void)Show;
- (void)Close;

@property (nonatomic) NSString *title;
@property (nonatomic) double progress;
@property (nonatomic, strong) void (^OnCancelOperation)();
@property (nonatomic, readonly) bool userCancelled;
@end
