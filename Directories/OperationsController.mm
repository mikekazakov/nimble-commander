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
}

-(id)init
{
    self = [super init];
    if (self)
    {
        m_Operations = [NSArray array];
    }
    return self;
}

-(void)AddOperation:(Operation *)_op
{
    assert(_op);
    
    [m_Operations addObject:_op];
}

-(void)Update
{
    // Remove finished operations from the list.
    int i = 0;
    while (i < m_Operations.count)
    {
        if ([[m_Operations objectAtIndex:i] IsFinished])
            [m_Operations removeObjectAtIndex:i];
        else
            ++i;
    }
}

@end
