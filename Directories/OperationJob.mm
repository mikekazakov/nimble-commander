//
//  OperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "OperationJob.h"

OperationJob::OperationJob()
:   m_State(StateReady),
    m_Paused(false),
    m_RequestStop(false),
    m_Progress(0.f)
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

float OperationJob::GetProgress() const
{
    return m_Progress;
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

void OperationJob::SetStopped()
{
    assert(m_State == StateRunning);
    
    m_State = StateStopped;
}

void OperationJob::SetCompleted()
{
    assert(m_State == StateRunning);
    
    m_State = StateCompleted;
}

bool OperationJob::CheckPauseOrStop(int _sleep_in_ms)
{
    while (m_Paused && !m_RequestStop) usleep(_sleep_in_ms*1000);
    
    return m_RequestStop;
}

void OperationJob::SetProgress(float _progress)
{
    if (_progress < 0.f) _progress = 0.f;
    else if (_progress > 1.f) _progress = 1.f;
    m_Progress = _progress;
}
