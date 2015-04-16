//
//  OperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationJob.h"
#import "Operation.h"

OperationJob::OperationJob():
    m_NoIdlePromise( IdleSleepPreventer::Instance().GetPromise() )
{
}

OperationJob::~OperationJob()
{
    assert(IsFinished());
}

void OperationJob::Start()
{
    assert(m_State == StateReady);
    if (m_State != StateReady) return;
    
    m_State = StateRunning;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^
    {
        Do();
        
        assert(IsFinished());
    });
}

void OperationJob::Pause()
{
    m_Paused = true;
}

void OperationJob::Resume()
{
    m_Paused = false;
}

void OperationJob::RequestStop()
{
    m_RequestStop = true;
}

bool OperationJob::IsFinished() const
{
    return m_State == StateStopped || m_State == StateCompleted;
}

bool OperationJob::IsPaused() const
{
    return m_Paused;
}

bool OperationJob::IsStopRequested() const
{
    return m_RequestStop;
}

OperationJob::State OperationJob::GetState() const
{
    return m_State;
}

OperationStats& OperationJob::GetStats()
{
    return m_Stats;
}

void OperationJob::SetStopped()
{
    assert(m_State == StateRunning);
    
    m_State = StateStopped;
}

void OperationJob::SetCompleted()
{
    assert(m_State == StateRunning);
    
    m_State = StateCompleted;
    
    [(Operation*)m_BaseOperation OnFinish];
}

bool OperationJob::CheckPauseOrStop(int _sleep_in_ms)
{
    if (m_Paused && !m_RequestStop)
    {
        m_Stats.PauseTimeTracking();
        while (m_Paused && !m_RequestStop)
        {
            usleep(_sleep_in_ms*1000);
        }
        m_Stats.ResumeTimeTracking();
    }
    
    return m_RequestStop;
}

void OperationJob::SetBaseOperation(Operation *_op)
{
    m_BaseOperation = _op;
}