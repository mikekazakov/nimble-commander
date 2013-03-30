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
    volatile OperationDialogController *m_Dialog;
}

- (id)initWithJob:(OperationJob *)_job
{
    self = [super init];
    if (self)
    {
        m_Job = _job;
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
    if (m_Dialog)
    {
        if (m_Dialog.IsVisible)
            [m_Dialog HideDialogWithResult:OperationDialogResultStop];
        else
            m_Dialog.Result = OperationDialogResultStop;
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

- (void)EnqueueDialog:(OperationDialogController *)_dialog
{
    [_dialog SetOperation:self];
    m_Dialog = _dialog;
}

- (BOOL)HasDialog
{
    return m_Dialog != nil;
}

- (void)ShowDialogForWindow:(NSWindow *)_parent
{
    assert([self HasDialog]);
    
    [m_Dialog ShowDialogFor:_parent];
}

- (void)OnDialogHidden:(OperationDialogController *)_dialog
{
    assert(m_Dialog == _dialog);
    
    if (_dialog.Result == OperationDialogResultNone) return;
    
    m_Dialog = nil;
    if (_dialog.Result == OperationDialogResultStop) [self Stop];
}

@end
