// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/Operations/Job.h"
#include <Habanero/IdleSleepPreventer.h>
#include <boost/core/demangle.hpp>
#include <thread>
#include <iostream>

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
    if( m_IsRunning || m_IsStopped )
        return;
    
    m_IsRunning = true;
    std::thread{ [this]{ Execute(); } }.detach();
}

void Job::Execute()
{
    const auto thread_title = "com.magnumbytes.nimblecommander." +
                              boost::core::demangle(typeid(*this).name());
    pthread_setname_np(thread_title.c_str());

    const auto sleep_preventer = IdleSleepPreventer::Instance().GetPromise();
    m_Stats.StartTiming();
    
    try {
        Perform();
    }
    catch( std::exception &e ) {
        std::cerr << "Error: operation " << typeid(*this).name() <<
            " has thrown an exeption: " << e.what() << "." << std::endl;
        Stop();
    }
    catch(...){
        std::cerr << "Error: operation " << typeid(*this).name() <<
            " has thrown an unknown exeption."<< std::endl;
        Stop();
    }
    
    if( !IsStopped() )
        SetCompleted();
    
    m_IsRunning = false;
    
    m_Stats.StopTiming();
    
    m_CallbackLock.lock();
    const auto callback = m_OnFinish;
    m_CallbackLock.unlock();
    if( callback )
        callback();
}

bool Job::IsRunning() const noexcept
{
    return m_IsRunning;
}

void Job::SetFinishCallback( std::function<void()> _callback )
{
    std::lock_guard<std::mutex> lock{m_CallbackLock};
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
    Resume();
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
    
    m_CallbackLock.lock();
    const auto callback = m_OnPause;
    m_CallbackLock.unlock();
    if( callback )
        callback();
}

void Job::Resume()
{
    if( !m_IsPaused )
        return;
    m_IsPaused = false;
    m_PauseCV.notify_all();
    
    m_CallbackLock.lock();
    const auto callback = m_OnResume;
    m_CallbackLock.unlock();
    if( callback )
        callback();
}

bool Job::IsPaused() const noexcept
{
    return m_IsPaused;
}

void Job::BlockIfPaused()
{
    if( m_IsPaused && !m_IsStopped ) {
        static std::mutex mutex;
        std::unique_lock<std::mutex> lock{mutex};
        const auto predicate = [this]{ return !m_IsPaused; };
        
        m_Stats.PauseTiming();
        m_PauseCV.wait(lock, predicate);
        m_Stats.ResumeTiming();
    }
}

void Job::SetPauseCallback( std::function<void()> _callback )
{
    LOCK_GUARD(m_CallbackLock)
        m_OnPause = move(_callback);
}

void Job::SetResumeCallback( std::function<void()> _callback )
{
    LOCK_GUARD(m_CallbackLock)
        m_OnResume = move(_callback);
}

}
