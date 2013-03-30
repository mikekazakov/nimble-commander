//
//  TimedDummyOperation.m
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "TimedDummyOperation.h"

#import "TimedDummyOperationJob.h"

@implementation TimedDummyOperation
{
    TimedDummyOperationJob m_Job;
}

- (id)initWithTime:(int)_seconds
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(self, _seconds);
    }
    return self;
}

- (TimedDummyOperationTestDialog *)AskUser:(int)_cur_time;
{
    TimedDummyOperationTestDialog *dialog = [[TimedDummyOperationTestDialog alloc] init];
    [dialog SetTime:_cur_time];
    
    [self EnqueueDialog:dialog];
    
    return dialog;
}

@end
