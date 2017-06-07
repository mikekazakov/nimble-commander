#pragma once

#include <functional>
#include <thread>

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
    OperationState State();

    // current status enquiry:
    // Status Status;

    // progress details enquiry:
    // Statistics Stats;

    // notifications:
    // NotifyOnStateChange()
    // NotifyOnFinish()
    // NotifyOnStop()

    void SetFinishCallback( std::function<void()> _callback );

    void Wait();
    bool Wait( std::chrono::nanoseconds _wait_for_time );

protected:
    virtual Job *GetJob();
    virtual void OnJobFinished();

private:
    void JobFinished();

    std::condition_variable m_FinishCV;
    std::function<void()> m_OnFinish;

};


}
