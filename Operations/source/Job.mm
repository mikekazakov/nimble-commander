#include "../include/Operations/Job.h"
#include <thread>

namespace nc::ops
{

Job::Job():
    m_IsRunning{false},
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
    
    auto task = [this]{
        Perform();
        m_IsRunning = false;
      
        std::function<void()> callback;
        m_OnFinishLock.lock();
        callback = m_OnFinish;
        m_OnFinishLock.unlock();
        if( callback )
            callback();
    };
    
    m_IsRunning = true;
    std::thread{ std::move(task) }.detach();
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
    m_IsStopped = true;
    OnStopped();
}

void Job::OnStopped()
{
}

void Job::SetCompleted()
{
    if( !m_IsCompleted )
        m_IsCompleted = true;
}

}
