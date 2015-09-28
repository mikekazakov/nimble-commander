//
//  OperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "OperationJob.h"

OperationJob::OperationJob():
    m_NoIdlePromise( IdleSleepPreventer::Instance().GetPromise() )
{
}

OperationJob::~OperationJob()
{
    if( !IsFinished() )
        fprintf(stderr, "OperationJob::~OperationJob(): operation was destroyed in a non-finished state!\n");
}

void OperationJob::Start()
{
    assert(m_State == State::Ready);
    if (m_State != State::Ready) return;
    
    m_State = State::Running;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, [=]
    {
        try
        {
            Do();
        }
        catch(exception &e)
        {
            cout << "Operation exception caught: " << e.what() << endl;
        }
        catch(exception *e)
        {
            cout << "Operation exception caught: " << e->what() << endl;
        }
        catch(...)
        {
            cout << "Caught an unhandled Operation exception!" << endl;
        }

        if(!IsFinished())
            throw logic_error("IsFinished() is not true after operation's Do() returned control");
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
    return m_State == State::Stopped || m_State == State::Completed;
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
    assert(m_State == State::Running);
    
    m_State = State::Stopped;
}

void OperationJob::SetCompleted()
{
    assert(m_State == State::Running);
    
    m_State = State::Completed;
    
    if(m_OnFinish)
        m_OnFinish();
}

bool OperationJob::CheckPauseOrStop(int _sleep_in_ms) const
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
