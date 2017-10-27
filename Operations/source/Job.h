// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <atomic>
#include <functional>
#include <mutex>

#include "Statistics.h"


namespace nc::ops
{

class Job
{
public:
    virtual ~Job();

    void Run();
    void Pause();
    void Resume();
    void Stop();
    
    bool IsRunning() const noexcept;
    bool IsPaused() const noexcept;
    bool IsStopped() const noexcept;
    bool IsCompleted() const noexcept;

    void SetFinishCallback( std::function<void()> _callback );
    void SetPauseCallback( std::function<void()> _callback );
    void SetResumeCallback( std::function<void()> _callback );
    
    class Statistics &Statistics();
    const class Statistics &Statistics() const;
    
protected:
    Job();
    virtual void Perform();
    virtual void OnStopped();

    void SetCompleted();
    void Execute();
    void BlockIfPaused();

private:
    std::atomic_bool        m_IsRunning;
    std::atomic_bool        m_IsPaused;
    std::atomic_bool        m_IsCompleted;
    std::atomic_bool        m_IsStopped;
    std::condition_variable m_PauseCV;
    
    std::function<void()>   m_OnFinish;
    std::function<void()>   m_OnPause;
    std::function<void()>   m_OnResume;
    std::mutex              m_CallbackLock;
    
    class Statistics      m_Stats;
};

}
