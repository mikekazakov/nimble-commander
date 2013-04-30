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
}

- (void)setIsPaused:(BOOL)IsPaused
{
    _IsPaused = IsPaused;
    if (IsPaused)
        m_Job->Pause();
    else
        m_Job->Resume();
}

- (id)initWithJob:(OperationJob *)_job
{
    self = [super init];
    if (self)
    {
        m_Job = _job;
        _DialogsCount = 0;
        _TargetPanel = nil;
        for (int i = 0; i < MaxDialogs; ++i) m_Dialogs[i] = nil;
    }
    return self;
}

- (void)Update
{
    OperationStats &stats = m_Job->GetStats();
    float progress = stats.GetProgress();
    if (_Progress != progress)
        self.Progress = progress;
    
    int time = int(stats.GetTime()/1000000);
    self.ShortInfo = [NSString stringWithFormat:@"time:%3i  %llu or %llu",
                      time/1000, stats.GetValue(), stats.GetMaxValue()];
}

- (void)Start
{
    if (m_Job->GetState() == OperationJob::StateReady)
        m_Job->Start();
}

- (void)Pause
{
    self.IsPaused = YES;
}

- (void)Resume
{
    self.IsPaused = NO;
}

- (void)Stop
{
    m_Job->RequestStop();
    
    while (_DialogsCount)
    {
        if (m_Dialogs[0].Result == OperationDialogResult::None)
            [m_Dialogs[0] CloseDialogWithResult:OperationDialogResult::Stop];
    }
}

- (BOOL)IsStarted
{
    return m_Job->GetState() != OperationJob::StateReady;
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
    m_Job->GetStats().PauseTimeTracking();
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        // Enqueue dialog.
        [_dialog OnDialogEnqueued:self];
        m_Dialogs[_DialogsCount] = _dialog;
        ++self.DialogsCount;
        
        // If operation is in process of stoppping, close the dialog.
        if (m_Job->IsStopRequested())
            [_dialog CloseDialogWithResult:OperationDialogResult::Stop];
        else
            NSBeep();
    });
}

- (void)ShowDialog;
{
    if (_DialogsCount)
        [m_Dialogs[0] ShowDialogForWindow:[NSApp mainWindow]];
}

- (void)OnDialogClosed:(id <OperationDialogProtocol>)_dialog
{
    // Remove dialog from the queue and shift other dialogs to the left.
    // Can't use memmove due to ARC, shift by hand.
    bool swap = false;
    for (int i = 0; i < _DialogsCount; ++i)
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
    --self.DialogsCount;
    
    m_Job->GetStats().ResumeTimeTracking();
    
    if (_dialog.Result == OperationDialogResult::Stop) [self Stop];
}

@end
