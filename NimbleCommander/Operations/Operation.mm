//
//  Operation.m
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/ByteCountFormatter.h>
#include "../../NimbleCommander/Bootstrap/AppDelegate.h"
#include "Operation.h"
#include "OperationJob.h"

NSError* ErrnoToNSError(int _error_code)
{
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:_error_code userInfo:nil];
}

NSError* ErrnoToNSError()
{
    return ErrnoToNSError(errno);
}

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

// informing AppDelegate about frontmost operation's progress
struct OperationsProgressReporter
{
private:
    static vector<void*> g_AllOperations;
    static mutex         g_AllOperationsMutex;
    
    static inline bool IsFrontmostOperation(void* _op) {
        if(g_AllOperations.empty())
            return false;
        return g_AllOperations.front() == _op;
    }

public:
    static void Register(void* _op) {
        lock_guard<mutex> guard(g_AllOperationsMutex);
        g_AllOperations.emplace_back(_op);
    }
    
    static void Unregister(void* _op) {
        lock_guard<mutex> guard(g_AllOperationsMutex);
        if(IsFrontmostOperation(_op))
            AppDelegate.me.progress = -1;
        
        auto it = find(begin(g_AllOperations), end(g_AllOperations), _op);
        if(it != end(g_AllOperations))
            g_AllOperations.erase(it);
    }
    
    static void Report(void* _op, double _progress) {
        lock_guard<mutex> guard(g_AllOperationsMutex);
        if(IsFrontmostOperation(_op))
            AppDelegate.me.progress = _progress;
    }
};

vector<void*> OperationsProgressReporter::g_AllOperations;
mutex         OperationsProgressReporter::g_AllOperationsMutex;

@implementation Operation
{
    OperationJob        *m_Job;
    vector<id<OperationDialogProtocol>> m_Dialogs;
    vector<void(^)()>   m_Handlers;
    double              m_Progress;
    bool                m_IsPaused;
    bool                m_IsIndeterminate;
    
    PanelController    *m_TargetPanel; // REMOVE ME LATER. MOVE TO CALLBACKS!!
}

@synthesize IsPaused = m_IsPaused;
@synthesize Progress = m_Progress;
@synthesize TargetPanel = m_TargetPanel;
@synthesize IsIndeterminate = m_IsIndeterminate;

- (milliseconds) ElapsedTime
{
    return m_Job->GetStats().GetTime();
}

- (OperationStats&) Stats
{
    return m_Job->GetStats();
}

- (void)setIsPaused:(bool)IsPaused
{
    if(m_IsPaused == IsPaused)
        return;

    m_IsPaused = IsPaused;
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
        m_TargetPanel = nil;
        m_Progress = 0;
        m_IsIndeterminate = true;
        m_IsPaused = false;
        
        __weak Operation *weak_self = self;
        m_Job->SetOnFinish([=]{
            if( Operation* strong_self = weak_self )
               [strong_self OnFinish];
        });
        
        OperationsProgressReporter::Register((__bridge void*)self);
    }
    return self;
}

- (void)dealloc
{
    OperationsProgressReporter::Unregister((__bridge void*)self);
}

- (void)Update
{
    OperationStats &stats = m_Job->GetStats();
    float progress = stats.GetProgress();
    if (m_Progress != progress)
        self.Progress = progress;
    

    double time = double(stats.GetTime().count())/1000.0;
    self.ShortInfo = [NSString stringWithFormat:@"time:%.0f, %llu of %llu (%.02f/s)",
                      time, stats.GetValue(), stats.GetMaxValue(),
                          stats.GetValue()/time];
}

- (void)Start
{
    if (m_Job->GetState() == OperationJob::State::Ready)
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
    
    while(!m_Dialogs.empty())
    {
        if (m_Dialogs.front().Result == OperationDialogResult::None)
            [m_Dialogs.front() CloseDialogWithResult:OperationDialogResult::Stop];
    }
    
    m_Handlers.clear(); // erase all hanging (possibly strong) links to self
}

- (bool)IsStarted
{
    return m_Job->GetState() != OperationJob::State::Ready;
}

- (bool)IsFinished
{
    return m_Job->IsFinished();
}

- (bool)IsCompleted
{
    return m_Job->GetState() == OperationJob::State::Completed;
}

- (bool)IsStopped
{
    return m_Job->GetState() == OperationJob::State::Stopped;
}

- (bool)DialogShown
{
    if(m_Dialogs.empty())
        return false;
 
    for(auto i: m_Dialogs)
        if(i.IsVisible)
            return true;

    return false;
}

- (void)EnqueueDialog:(id <OperationDialogProtocol>)_dialog
{
    m_Job->GetStats().PauseTimeTracking();
    
    dispatch_to_main_queue( [=]{
        // Enqueue dialog.
        [_dialog OnDialogEnqueued:self];

        [self willChangeValueForKey:@"DialogsCount"];
        m_Dialogs.emplace_back(_dialog);
        [self didChangeValueForKey:@"DialogsCount"];        
        
        // If operation is in process of stoppping, close the dialog.
        if (m_Job->IsStopRequested())
            [_dialog CloseDialogWithResult:OperationDialogResult::Stop];
        else
            NSBeep();
    });
}

- (void)ShowDialog
{
    if (!m_Dialogs.empty())
        [m_Dialogs.front() showDialogForWindow:[NSApp mainWindow]];
}

- (id <OperationDialogProtocol>) FrontmostDialog
{
    if(!m_Dialogs.empty())
        return m_Dialogs.front();
    return nil;
}

- (void)OnDialogClosed:(id <OperationDialogProtocol>)_dialog
{
    // Remove dialog from the queue and shift other dialogs to the left.
    [self willChangeValueForKey:@"DialogsCount"];
    m_Dialogs.erase(remove_if(begin(m_Dialogs),
                              end(m_Dialogs),
                              [=](auto _t) {
                                  return _t == _dialog;
                              }),
                    end(m_Dialogs)
                    );
    [self didChangeValueForKey:@"DialogsCount"];
    
    m_Job->GetStats().ResumeTimeTracking();
    
    if (_dialog.Result == OperationDialogResult::Stop)
        [self Stop];
}

- (NSString*) ProduceDescriptionStringForBytesProcess
{
    OperationStats &stats = m_Job->GetStats();
    milliseconds time = stats.GetTime();
    uint64_t copy_speed = 0;
    if (time.count() > 0)
        copy_speed = stats.GetValue()*1000/time.count();
    uint64_t eta_value = 0;
    if (copy_speed)
        eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
        
    char eta[18] = {0};
    if (copy_speed)
        FormHumanReadableTimeRepresentation(eta_value, eta);

    NSString *desc = nil;
    auto &f = ByteCountFormatter::Instance();
    if (copy_speed)
        desc = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
                          f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive8),
                          f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive8),
                          f.ToNSString(copy_speed, ByteCountFormatter::Adaptive8),
                          eta];
    else
        desc = [NSString stringWithFormat:@"%@ of %@ - %@/s",
                          f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive8),
                          f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive8),
                          f.ToNSString(copy_speed, ByteCountFormatter::Adaptive8)];
    
    return desc;
}


- (void)setProgress:(double)Progress
{
    OperationsProgressReporter::Report((__bridge void*)self, Progress);
    
    m_Progress = Progress;
    if(m_IsIndeterminate == true && Progress > 0.0001)
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

- (int) DialogsCount
{
    return (int)m_Dialogs.size();
}

@end
