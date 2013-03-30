//
//  TimedDummyOperation.h
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#import "TimedDummyOperationTestDialog.h"

@interface TimedDummyOperation : Operation

- (id)initWithTime:(int)_seconds;

- (TimedDummyOperationTestDialog *)AskUser:(int)_cur_time;

@end
