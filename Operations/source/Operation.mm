#include "../include/Operations/Operation.h"
#include "../include/Operations/Job.h"

namespace nc::ops
{

Operation::Operation()
{
}

Operation::~Operation()
{
}

Job *Operation::GetJob() noexcept
{
    return nullptr;
}

const Job *Operation::GetJob() const
{
    return const_cast<Operation*>(this)->GetJob();
}

const class Statistics &Operation::Statistics() const
{
    if( auto job = GetJob() )
        return job->Statistics();
    throw logic_error("Operation::Statistics(): no valid Job object to access to");
}

OperationState Operation::State() const
{
    if( auto j = GetJob() ) {
        if( j->IsPaused() )
            return OperationState::Paused;
        if( j->IsRunning() )
            return OperationState::Running;
        if( j->IsCompleted() )
            return OperationState::Completed;
        if( j->IsStopped() )
            return OperationState::Stopped;
    }
    return OperationState::Cold;
}

void Operation::Start()
{
    if( auto j = GetJob() ) {
        if( j->IsRunning() )
            return;
    
        j->SetFinishCallback(   [this]{ JobFinished();  });
        j->SetPauseCallback(    [this]{ JobPaused();    });
        j->SetResumeCallback(   [this]{ JobPaused();    });
        
        j->Run();
        
        FireObservers( NotifyAboutStart );
    }
}

void Operation::Pause()
{
    if( auto j = GetJob() )
        j->Pause();
}

void Operation::Resume()
{
    if( auto j = GetJob() )
        j->Resume();
}

void Operation::Stop()
{
    if( auto j = GetJob() )
        j->Stop();
} 

void Operation::Wait() const
{
    const auto pred = [this]{
        const auto s = State();
        return s != OperationState::Running && s != OperationState::Paused;
    };
    if( pred() )
        return;
    
    std::mutex m;
    std::unique_lock<std::mutex> lock{m};
    m_FinishCV.wait(lock, pred);
}

bool Operation::Wait( std::chrono::nanoseconds _wait_for_time ) const
{
    const auto pred = [this]{
        const auto s = State();
        return s != OperationState::Running && s != OperationState::Paused;
    };
    if( pred() )
        return true;
    
    std::mutex m;
    std::unique_lock<std::mutex> lock{m};
    return m_FinishCV.wait_for(lock, _wait_for_time, pred);
}

void Operation::JobFinished()
{
    OnJobFinished();
    
    const auto state = State();
    if( state == OperationState::Completed )
        FireObservers( NotifyAboutCompletion );
    if( state == OperationState::Stopped )
        FireObservers( NotifyAboutStop );

    m_FinishCV.notify_all();
}

void Operation::JobPaused()
{
    OnJobPaused();
    FireObservers( NotifyAboutPause );
}

void Operation::JobResumed()
{
    OnJobResumed();
    FireObservers( NotifyAboutResume );
}

//void Operation::SetFinishCallback( std::function<void()> _callback )
//{
//    m_OnFinish = _callback;
//}

//void Operation::FireObserversOnStateChange()
//{
//    switch( State() ) {
//  cabreak;
//
//  default:
//    break;
//}

//}

void Operation::OnJobFinished()
{
}

void Operation::OnJobPaused()
{
}

void Operation::OnJobResumed()
{
}

Operation::ObservationTicket Operation::Observe
( uint64_t _notification_mask, function<void()> _callback )
{
    return AddTicketedObserver(move(_callback), _notification_mask);
}

void Operation::ObserveUnticketed( uint64_t _notification_mask, function<void()> _callback )
{
    return AddUnticketedObserver(move(_callback), _notification_mask);
}

}
