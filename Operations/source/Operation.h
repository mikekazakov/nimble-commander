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
    Stopped     = 2,
    Completed   = 3
};

class Operation
{
public:
    Operation();
    ~Operation();

    // control:
    void Start();
    void Stop();
    
    // general state enquiry:
    OperationState State() const;

    // current status enquiry:
    // Status Status;

    // progress details enquiry:
    // Statistics Stats;

    // notifications:
    // NotifyOnStateChange()
    // NotifyOnFinish()
    // NotifyOnStop()

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
