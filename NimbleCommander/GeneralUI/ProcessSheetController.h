// Copyright (C) 2014-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface ProcessSheetController : NSWindowController

- (void)Show;
- (void)Close;

@property NSString *title;
@property (nonatomic) IBOutlet NSProgressIndicator *Progress;
@property (nonatomic, strong) void (^OnCancelOperation)();
@property (nonatomic, readonly) bool userCancelled;
@end
