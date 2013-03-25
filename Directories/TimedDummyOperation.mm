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
        m_Job.Init(_seconds);
    }
    return self;
}

@end
