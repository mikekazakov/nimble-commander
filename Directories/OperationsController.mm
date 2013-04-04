//
//  OperationsController.m
//  Directories
//
//  Created by Pavel Dogurevich on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationsController.h"

// "Private" methods' declarations.
@interface OperationsController ()

- (BOOL)CanOperationStart:(Operation *)_op;

- (void)Update;

// Insertion and removal of operations in/from array. Necessary for bindings.
- (void)insertObject:(Operation *)_object inOperationsAtIndex:(NSUInteger)_index;
- (void)removeObjectFromOperationsAtIndex:(NSUInteger)_index;

@end


@implementation OperationsController
{
    NSMutableArray *m_Operations;
    NSTimer* m_UpdateTimer;
}

@synthesize Operations = m_Operations;

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
            [self removeObjectFromOperationsAtIndex:i];
            continue;
        }
        
        ++i;
    }
}

- (void)insertObject:(Operation *)_object inOperationsAtIndex:(NSUInteger)_index
{
    [m_Operations insertObject:_object atIndex:_index];
}

- (void)removeObjectFromOperationsAtIndex:(NSUInteger)_index
{
    [m_Operations removeObjectAtIndex:_index];
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
    
    [self insertObject:_op inOperationsAtIndex:m_Operations.count];
    
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
