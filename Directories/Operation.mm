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

#import <algorithm>

const int MaxDialogs = 2;

@implementation Operation
{
    OperationJob *m_Job;
    id<OperationDialogProtocol> m_Dialogs[MaxDialogs];
    int m_DialogsCount;
}

- (id)initWithJob:(OperationJob *)_job
{
    self = [super init];
    if (self)
    {
        m_Job = _job;
        m_DialogsCount = 0;
        for (int i = 0; i < MaxDialogs; ++i) m_Dialogs[i] = nil;
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
    m_Job->RequestStop();
    
    @synchronized(self)
    {
        for (int i = 0; i < m_DialogsCount; ++i)
        {
            if (m_Dialogs[i].Result == OperationDialogResult::None)
                [m_Dialogs[i] CloseDialogWithResult:OperationDialogResult::Stop];
        }
    }
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
    @synchronized(self)
    {
        // Enqueue dialog.
        [_dialog OnDialogEnqueued:self];
        m_Dialogs[m_DialogsCount++] = _dialog;
        
        // If operation is in process of stoppping, close the dialog.
        if (m_Job->IsStopRequested())
            [_dialog CloseDialogWithResult:OperationDialogResult::Stop];
    }
}

- (int)GetDialogsCount
{
    return m_DialogsCount;
}

- (void)ShowDialogForWindow:(NSWindow *)_parent
{
    @synchronized(self)
    {
        if (m_DialogsCount)
            [m_Dialogs[0] ShowDialogForWindow:_parent];
    }
}

- (void)OnDialogClosed:(id <OperationDialogProtocol>)_dialog
{
    @synchronized(self)
    {
        // Remove dialog from the queue and shift other dialogs to the left.
        // Can't use memmove due to ARC, shift by hand.
        bool swap = false;
        for (int i = 0; i < m_DialogsCount; ++i)
        {
            if (swap)
            {
                id <OperationDialogProtocol> tmp = m_Dialogs[i];
                m_Dialogs[i] = m_Dialogs[i - 1];
                m_Dialogs[i - 1] = tmp;
            }
            else if (m_Dialogs[i] == _dialog)
            {
                assert(!swap);
                swap = true;
            }
        }
        
        assert(swap);
        --m_DialogsCount;
    }
    
    if (_dialog.Result == OperationDialogResult::Stop) [self Stop];
}

@end
