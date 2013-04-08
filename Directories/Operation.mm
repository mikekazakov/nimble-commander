//
//  Operation.m
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"

#import "OperationJob.h"
#import "OperationDialogController.h"

@implementation Operation
{
    OperationJob *m_Job;
    NSMutableArray *m_Dialogs;
}

- (id)initWithJob:(OperationJob *)_job
{
    self = [super init];
    if (self)
    {
        m_Job = _job;
        m_Dialogs = [NSMutableArray array];
    }
    return self;
}

- (float)GetProgress
{
    return m_Job->GetProgress();
}

- (NSString *)GetCaption
{
    return [NSString stringWithFormat:@"Dummy caption %p", self];
}

- (void)Start
{
    if (m_Job->GetState() == OperationJob::StateReady)
        m_Job->Start();
}

- (void)Pause
{
    m_Job->Pause();
}

- (void)Resume
{
    m_Job->Resume();
}

- (void)Stop
{
    for (id <OperationDialogProtocol> dialog in m_Dialogs)
    {
        if (dialog.Result == OperationDialogResult::None)
            [dialog CloseDialogWithResult:OperationDialogResult::Stop];
    }
    
    m_Job->RequestStop();
}

- (BOOL)IsStarted
{
    return m_Job->GetState() != OperationJob::StateReady;
}

- (BOOL)IsPaused
{
    return m_Job->IsPaused();
}

- (BOOL)IsFinished
{
    return m_Job->IsFinished();
}

- (BOOL)IsCompleted
{
    return m_Job->GetState() == OperationJob::StateCompleted;
}

- (BOOL)IsStopped
{
    return m_Job->GetState() == OperationJob::StateStopped;
}

- (void)EnqueueDialog:(id <OperationDialogProtocol>)_dialog
{
    @synchronized(m_Dialogs)
    {
        [_dialog OnDialogEnqueued:self];
        [m_Dialogs addObject:_dialog];
    }
}

- (BOOL)HasDialog
{
    return m_Dialogs.count > 0;
}

- (void)ShowDialogForWindow:(NSWindow *)_parent
{
    @synchronized(m_Dialogs)
    {
        if (m_Dialogs.count > 0)
            [m_Dialogs[0] ShowDialogForWindow:_parent];
    }
}

- (void)OnDialogClosed:(id <OperationDialogProtocol>)_dialog
{
    assert([m_Dialogs containsObject:_dialog]);
    
    @synchronized(m_Dialogs)
    {
        [m_Dialogs removeObject:_dialog];
    }
    if (_dialog.Result == OperationDialogResult::Stop) [self Stop];
}

@end
