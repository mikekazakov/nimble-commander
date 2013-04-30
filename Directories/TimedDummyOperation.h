//
//  TimedDummyOperation.h
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#import "OperationDialogAlert.h"
#import "TimedDummyOperationTestDialog.h"

@interface TimedDummyOperation : Operation

- (id)initWithTime:(int)_seconds;

- (void)Update;

- (TimedDummyOperationTestDialog *)AskUser:(int)_cur_time;
- (OperationDialogAlert *)AskUserAlert;

@end
