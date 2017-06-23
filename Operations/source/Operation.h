#pragma once

#include <functional>
#include <thread>
#include <Habanero/ScopedObservable.h>

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

class Operation : private ScopedObservableBase
{
public:
    Operation();
    virtual ~Operation();

    void Start();
    void Pause();
    void Resume();
    void Stop();
    
    OperationState State() const;

    const class Statistics &Statistics() const;

    void Wait() const;
    bool Wait( std::chrono::nanoseconds _wait_for_time ) const;

    enum {
        NotifyAboutStart        = 1<<0,
        NotifyAboutPause        = 1<<1,
        NotifyAboutResume       = 1<<2,
        NotifyAboutStop         = 1<<3,
        NotifyAboutCompletion   = 1<<4,
        NotifyAboutFinish       = NotifyAboutStop | NotifyAboutCompletion,
        NotifyAboutStateChange  = NotifyAboutStart | NotifyAboutPause | NotifyAboutResume |
                                  NotifyAboutStop | NotifyAboutCompletion
    };

    using ObservationTicket = ScopedObservableBase::ObservationTicket;
    ObservationTicket Observe( uint64_t _notification_mask, function<void()> _callback );
    void ObserveUnticketed( uint64_t _notification_mask, function<void()> _callback );

protected:
    virtual Job *GetJob() noexcept;
    const Job *GetJob() const;
    virtual void OnJobFinished();
    virtual void OnJobPaused();
    virtual void OnJobResumed();

private:
    Operation(const Operation&) = delete;
    void operator=(const Operation&) = delete;
    void JobFinished();
    void JobPaused();
    void JobResumed();
    
    mutable std::condition_variable m_FinishCV;
};


}
