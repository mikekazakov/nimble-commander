//
//  OperationsController.m
//  Directories
//
//  Created by Pavel Dogurevich on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationsController.h"

@implementation OperationsController
{
    NSMutableArray *m_Operations;
    NSTimer* m_UpdateTimer;
}

- (BOOL)CanOperationStart:(Operation *)_op
{
    // TODO: implement
    return YES;
}

- (void)Update
{
    // Updating operations:
    int i = 0;
    while (i < m_Operations.count)
    {
        Operation *op = m_Operations[i];
        
        if (![op IsStarted] && [self CanOperationStart:op])
            [op Start];
        
        if ([op IsFinished])
        {
            // Remove finished operation from the collection.
            [m_Operations removeObjectAtIndex:i];
            continue;
        }
        
        ++i;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        m_Operations = [NSMutableArray array];
        
        m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                         target:self
                                                       selector:@selector(Update)
                                                       userInfo:nil
                                                        repeats:YES];
    }
    return self;
}

- (void)AddOperation:(Operation *)_op
{
    assert(_op);
    assert(![_op IsStarted]);
    
    [m_Operations addObject:_op];
    
    if ([self CanOperationStart:_op])
        [_op Start];
}

- (Operation *)GetOperation:(NSUInteger)_index
{
    if (_index >= m_Operations.count) return nil;
    return m_Operations[_index];
}

- (NSUInteger)GetOperationsCount
{
    return m_Operations.count;
}

@end
