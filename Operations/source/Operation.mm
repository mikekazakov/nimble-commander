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

Job *Operation::GetJob()
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
    
        j->SetFinishCallback(
            [this]{ JobFinished();
        });
    
        j->Run();
    }
}

void Operation::Stop()
{
    if( auto j = GetJob() )
        j->Stop();
} 

void Operation::Wait() const
{
    const auto pred = [this]{ return State() != OperationState::Running; };
    if( pred() )
        return;
    
    std::mutex m;
    std::unique_lock<std::mutex> lock{m};
    m_FinishCV.wait(lock, pred);
}

bool Operation::Wait( std::chrono::nanoseconds _wait_for_time ) const
{
    const auto pred = [this]{ return State() != OperationState::Running; };
    if( pred() )
        return true;
    
    std::mutex m;
    std::unique_lock<std::mutex> lock{m};
    return m_FinishCV.wait_for(lock, _wait_for_time, pred);
}

void Operation::JobFinished()
{
    OnJobFinished();
    
    if( m_OnFinish )
        m_OnFinish();
    
    m_FinishCV.notify_all();
}

void Operation::SetFinishCallback( std::function<void()> _callback )
{
    m_OnFinish = _callback;
}

void Operation::OnJobFinished()
{
}

}
