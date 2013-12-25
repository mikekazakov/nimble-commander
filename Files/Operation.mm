//
//  Operation.m
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <algorithm>
#import <vector>
#import "Operation.h"
#import "OperationJob.h"
#import "OperationDialogController.h"
#import "Common.h"

using namespace std;

static void FormHumanReadableTimeRepresentation(uint64_t _time, char _out[18])
{
    if(_time < 60) // seconds
    {
        sprintf(_out, "%llu s", _time);
    }
    else if(_time < 60*60) // minutes
    {
        sprintf(_out, "%llu min", (_time + 30)/60);
    }
    else if(_time < 24*3600lu) // hours
    {
        sprintf(_out, "%llu h", (_time + 1800)/3600);
    }
    else if(_time < 31*86400lu) // days
    {
        sprintf(_out, "%llu d", (_time + 43200)/86400lu);
    }
}

static void FormHumanReadableSizeRepresentation(uint64_t _sz, char _out[18])
{
    if(_sz < 1024) // bytes
    {
        sprintf(_out, "%3llu", _sz);
    }
    else if(_sz < 1024lu * 1024lu) // kilobytes
    {
        double size = _sz/1024.0;
        sprintf(_out, "%.1f KB", size);
    }
    else if(_sz < 1024lu * 1048576lu) // megabytes
    {
        double size = (_sz/1024)/1024.0;
        sprintf(_out, "%.1fMB", size);
    }
    else if(_sz < 1024lu * 1073741824lu) // gigabytes
    {
        double size = (_sz/1048576lu)/1024.0;
        sprintf(_out, "%.1fGB", size);
    }
    else if(_sz < 1024lu * 1099511627776lu) // terabytes
    {
        double size = (_sz/1073741824lu)/1024.0;
        sprintf(_out, "%.1f TB", size);
    }
    else if(_sz < 1024lu * 1125899906842624lu) // petabytes
    {
        double size = (_sz/1099511627776lu)/1024.0;
        sprintf(_out, "%.1f PB", size);
    }
}


const int MaxDialogs = 2;

@implementation Operation
{
    OperationJob *m_Job;
    id<OperationDialogProtocol> m_Dialogs[MaxDialogs];
    vector<void(^)()> m_Handlers;
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
        _Progress = 0;
        _IsIndeterminate = true;
        
        for (int i = 0; i < MaxDialogs; ++i) m_Dialogs[i] = nil;
        
        _job->SetBaseOperation(self);
    }
    return self;
}

- (void)Update
{
    OperationStats &stats = m_Job->GetStats();
    float progress = stats.GetProgress();
    if (_Progress != progress)
        self.Progress = progress;
    

    double time = stats.GetTime()/1000.0;
    self.ShortInfo = [NSString stringWithFormat:@"time:%.0f, %llu of %llu (%.02f/s)",
                      time, stats.GetValue(), stats.GetMaxValue(),
                          stats.GetValue()/time];
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
    
    dispatch_to_main_queue( ^(){
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

- (NSString*) ProduceDescriptionStringForBytesProcess
{
    OperationStats &stats = m_Job->GetStats();
    int time = stats.GetTime();
    uint64_t copy_speed = 0;
    if (time)
        copy_speed = stats.GetValue()*1000/time;
    uint64_t eta_value = 0;
    if (copy_speed)
        eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
        
    char copied[18] = {0}, total[18] = {0}, speed[18] = {0}, eta[18] = {0};
    FormHumanReadableSizeRepresentation(stats.GetValue(), copied);
    FormHumanReadableSizeRepresentation(stats.GetMaxValue(), total);
    FormHumanReadableSizeRepresentation(copy_speed, speed);
    if (copy_speed)
        FormHumanReadableTimeRepresentation(eta_value, eta);

    NSString *desc = nil;
    if (copy_speed)
        desc = [NSString stringWithFormat:@"%s of %s - %s/s - %s",
                            copied, total, speed, eta];
    else
        desc = [NSString stringWithFormat:@"%s of %s - %s/s",
                            copied, total, speed];
    return desc;
}


- (void) setProgress:(float)Progress
{
    _Progress = Progress;
    if(_IsIndeterminate == true && Progress > 0.0001f)
        self.IsIndeterminate = false;
}

- (void)OnFinish
{
    for(auto i: m_Handlers)
        i();
    m_Handlers.clear(); // erase all hanging (possibly strong) links to self
}

- (void)AddOnFinishHandler:(void (^)())_handler
{
    m_Handlers.push_back(_handler);
}

@end
