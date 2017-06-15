#include "../include/Operations/Job.h"
#include <thread>

namespace nc::ops
{

Job::Job():
    m_IsRunning{false},
    m_IsPaused{false},
    m_IsCompleted{false},
    m_IsStopped{false}
{
}

Job::~Job()
{
}

void Job::Perform()
{
}

void Job::Run()
{
    if( m_IsRunning )
        return;
    
    m_IsRunning = true;
    std::thread{ [this]{ Execute(); } }.detach();
}

void Job::Execute()
{
    m_Stats.StartTiming();
    Perform();
    m_IsRunning = false;
    m_Stats.StopTiming();
    
    std::function<void()> callback;
    m_OnFinishLock.lock();
    callback = m_OnFinish;
    m_OnFinishLock.unlock();
    if( callback )
        callback();
}

bool Job::IsRunning() const noexcept
{
    return m_IsRunning;
}

void Job::SetFinishCallback( std::function<void()> _callback )
{
    std::lock_guard<std::mutex> lock{m_OnFinishLock};
    m_OnFinish = std::move(_callback);
}

bool Job::IsCompleted() const noexcept
{
    return m_IsCompleted;
}

bool Job::IsStopped() const noexcept
{
    return m_IsStopped;
}

void Job::Stop()
{
    if( m_IsStopped )
        return;
    Resume();
    m_IsStopped = true;
    OnStopped();
}

void Job::OnStopped()
{
}

void Job::SetCompleted()
{
    if( m_IsCompleted )
        return;

    Resume();
    m_IsCompleted = true;
}

class Statistics &Job::Statistics()
{
    return m_Stats;
}

const class Statistics &Job::Statistics() const
{
    return m_Stats;
}

void Job::Pause()
{
    if( m_IsPaused || m_IsCompleted || m_IsStopped )
        return;
    m_IsPaused = true;
}

void Job::Resume()
{
    if( !m_IsPaused )
        return;
    m_IsPaused = false;
    m_PauseCV.notify_all();
}

bool Job::IsPaused() const noexcept
{
    return m_IsPaused;
}

void Job::BlockIfPaused()
{
    if( m_IsPaused && !m_IsStopped ) {
        static mutex mutex;
        unique_lock<std::mutex> lock{mutex};
        const auto predicate = [this]{ return !m_IsPaused; };
        
        m_Stats.PauseTiming();
        m_PauseCV.wait(lock, predicate);
        m_Stats.ResumeTiming();
    }
}

}
