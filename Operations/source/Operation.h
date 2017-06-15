#pragma once

#include <functional>
#include <thread>

#include "Statistics.h"

namespace nc::ops
{

class Job;

enum class OperationState
{
    Cold        = 0,
    Running     = 1,
    Paused      = 2,
    Stopped     = 3,
    Completed   = 4
};

class Operation
{
public:
    Operation();
    ~Operation();

    void Start();
    void Pause();
    void Resume();
    void Stop();
    
    OperationState State() const;

    const class Statistics &Statistics() const;

    void SetFinishCallback( std::function<void()> _callback );

    void Wait() const;
    bool Wait( std::chrono::nanoseconds _wait_for_time ) const;

protected:
    virtual Job *GetJob();
    const Job *GetJob() const;
    virtual void OnJobFinished();

private:
    void JobFinished();

    mutable std::condition_variable m_FinishCV;
    std::function<void()> m_OnFinish;
};


}
