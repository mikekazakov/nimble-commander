//
//  ProcessSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 28.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

@interface ProcessSheetController : NSWindowController

- (void)Show;
- (void)Close;

@property NSString *title;
@property (strong) IBOutlet NSProgressIndicator *Progress;
@property (nonatomic, strong) void (^OnCancelOperation)();
@property (nonatomic, readonly) bool userCancelled;
@end
