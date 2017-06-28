#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>
#include <thread>
#include <condition_variable>
#include <Habanero/ScopedObservable.h>
#include "Statistics.h"

class VFSHost;

namespace nc::ops
{

class Job;
struct AsyncDialogResponse;

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

    void SetDialogCallback(function<bool(NSWindow *, function<void(NSModalResponse)>)> _callback);
    bool IsWaitingForUIResponse() const noexcept;
    void AbortUIWaiting() noexcept;
    
protected:
    virtual Job *GetJob() noexcept;
    virtual void OnJobFinished();
    virtual void OnJobPaused();
    virtual void OnJobResumed();
    bool IsInteractive() const noexcept;
    void Show( NSWindow *_dialog, shared_ptr<AsyncDialogResponse> _response );
    void WaitForDialogResponse( shared_ptr<AsyncDialogResponse> _response );
    void ReportHaltReason( NSString *_message, int _error, const string &_path, VFSHost &_vfs );

private:
    Operation(const Operation&) = delete;
    void operator=(const Operation&) = delete;
    const Job *GetJob() const;
    void JobFinished();
    void JobPaused();
    void JobResumed();
    
    mutable std::condition_variable m_FinishCV;
    
    function<bool(NSWindow *dialog, function<void(NSModalResponse response)>)> m_DialogCallback;
    mutable spinlock m_DialogCallbackLock;
    
    weak_ptr<AsyncDialogResponse> m_PendingResponse;
    mutable spinlock m_PendingResponseLock;
};

}
