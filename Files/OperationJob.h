//
//  OperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/IdleSleepPreventer.h>
#include "OperationStats.h"

class OperationJob
{
public:
    enum class State
    {
        Ready,
        Running,
        Stopped,
        Completed
    };
    
    OperationJob();
    virtual ~OperationJob();
    
    void Start();
    void Pause();
    void Resume();
    void RequestStop();
    
    bool IsFinished() const;
    bool IsPaused() const;
    bool IsStopRequested() const;
    
    State GetState() const;
    
    OperationStats& GetStats();
    
    template <typename T>
    void SetOnFinish(T _t) { m_OnFinish = move(_t); } // should be called only by Operation class
    
protected:
    virtual void Do() = 0;
    
    // Puts job in stopped state. Should be called just before exiting from the internal thread.
    void SetStopped();
    // Puts job in completed state. Should be called just before exiting from the internal thread.
    void SetCompleted();
    
    // Helper function that does 2 things:
    // - if m_Pause is true, it waits for m_Pause to become false, checking the value each
    //   _sleep_in_ms milliseconds
    // - if m_RequestStop is true, it returns true as soon as possible.
    // Typical usage in Do method:
    // if (CheckPauseOrStop())
    // {
    //      SetStopped();
    //      return;
    // }
    bool CheckPauseOrStop(int _sleep_in_ms = 100) const;
    
    mutable OperationStats m_Stats;
    
private:
    // Current state of the job.
    volatile State m_State = State::Ready;
    
    // Indicates that internal thread should pause execution.
    // Internal thread only reads this variable.
    volatile bool m_Paused = false;
    
    // Requests internal thread to stop execution.
    // Internal thread only reads this variable.
    volatile bool m_RequestStop = false;
    
    // preventing system from idle when any Job object is present
    unique_ptr<IdleSleepPreventer::Promise> m_NoIdlePromise;
    
    // called in SetCompleted only
    function<void()> m_OnFinish;
    
    // Disable copy constructor and operator.
    OperationJob(const OperationJob&) = delete;
    const OperationJob& operator=(const OperationJob&) = delete;
};
