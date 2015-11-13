//
//  OperationsController.m
//  Directories
//
//  Created by Pavel Dogurevich on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../Common.h"
#include "OperationsController.h"

static const milliseconds g_DialogAutoTriggeringTreshMS = 2000ms;

@implementation OperationsController
{
    NSMutableArray*         m_Operations;
    vector<__weak id <OperationDialogProtocol>> m_AutoTriggeredDialogs;
    NSTimer*                m_UpdateTimer;
    bool                    m_Stop;
}

@synthesize Operations = m_Operations;

- (BOOL)CanOperationStart:(Operation *)_op
{
    // TODO: implement
    return YES;
}

- (void)Update
{
    // Updating operations and OperationsWithDialogsCount property.
    Operation *operation_to_show_dialog = nil;
    
    int ops_with_dialogs = 0;
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
        
        [op Update];
        
        if (op.DialogsCount != 0)
        {
            ++ops_with_dialogs;

            if(op.ElapsedTime < g_DialogAutoTriggeringTreshMS &&
               !op.DialogShown &&
               find(begin(m_AutoTriggeredDialogs),
                    end(m_AutoTriggeredDialogs),
                    op.FrontmostDialog
                    ) == end(m_AutoTriggeredDialogs) &&
               !operation_to_show_dialog)
                operation_to_show_dialog = op;
        }
        
        ++i;
    }
    
    // Update property if needed.
    if (ops_with_dialogs != _OperationsWithDialogsCount)
    {
        self.OperationsWithDialogsCount = ops_with_dialogs;

        // 'garbage collection' in m_AutoTriggeredDialogs
        m_AutoTriggeredDialogs.erase(remove_if(begin(m_AutoTriggeredDialogs),
                                               end(m_AutoTriggeredDialogs),
                                               [](auto _t) {
                                                   return ((id <OperationDialogProtocol>)_t) == nil;
                                                }),
                                     end(m_AutoTriggeredDialogs)
                                     );
    }
    
    if(operation_to_show_dialog &&
       !self.AnyDialogShown &&
       // BAAAAD approach. need to connect a current window and operation directly.
       // this may cause confusion, since operation can show an aleart on other window than from it was started:
       [NSApp mainWindow].attachedSheet == nil)
    {
        assert(operation_to_show_dialog.FrontmostDialog != nil);
        m_AutoTriggeredDialogs.emplace_back(operation_to_show_dialog.FrontmostDialog);
        [operation_to_show_dialog ShowDialog];
    }
}

- (void)insertObject:(Operation *)_object inOperationsAtIndex:(NSUInteger)_index
{
    [m_Operations insertObject:_object atIndex:_index];
    ++self.OperationsCount;
    
    if (!m_UpdateTimer)
    {
        m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.033
                                                         target:self
                                                       selector:@selector(Update)
                                                       userInfo:nil
                                                        repeats:YES];
        [m_UpdateTimer setSafeTolerance];
    }
}

- (void)removeObjectFromOperationsAtIndex:(NSUInteger)_index
{
    [m_Operations removeObjectAtIndex:_index];
    --self.OperationsCount;
    
    if (_OperationsCount == 0)
    {
        self.OperationsWithDialogsCount = 0;
        [m_UpdateTimer invalidate];
        m_UpdateTimer = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        m_Operations = [NSMutableArray array];
    }
    return self;
}

- (void)Stop
{
    m_Stop = true;
    
    for (Operation *op in m_Operations)
        [op Stop];
    
    if (m_Operations.count == 0) return;
    
    for (;;)
    {
        int i = 0;
        while (i < m_Operations.count)
        {
            Operation *op = m_Operations[i];
            
            if ([op IsFinished])
            {
                // Remove finished operation from the collection.
                [self removeObjectFromOperationsAtIndex:i];
                continue;
            }
            
            ++i;
        }

        if (m_Operations.count == 0) break;
        
        usleep(10*1000);
    }
}

- (void)AddOperation:(Operation *)_op
{
    assert(_op);
    assert(![_op IsStarted]);
    
    if (m_Stop) return;
    
    [self insertObject:_op inOperationsAtIndex:m_Operations.count];
    
    if ([self CanOperationStart:_op])
        [_op Start];
}

- (Operation *)GetOperation:(NSUInteger)_index
{
    if (_index >= m_Operations.count) return nil;
    return m_Operations[_index];
}


- (bool)AnyDialogShown
{
    for(Operation *op in m_Operations)
        if(op.DialogShown)
            return true;
    return false;
}

@end
