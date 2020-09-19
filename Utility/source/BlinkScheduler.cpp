// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.

#include "../include/Utility/BlinkScheduler.h"
#include <Habanero/mach_time.h>
#include <Habanero/dispatch_cpp.h>
#include <stdexcept>

namespace nc::utility {

using namespace std::chrono_literals;

BlinkScheduler::BlinkScheduler::DefaultIO BlinkScheduler::DefaultIO::Instance;

struct BlinkScheduler::Impl : std::enable_shared_from_this<Impl> {
    std::function<void()>                       m_OnBlink;
    std::chrono::milliseconds                   m_BlinkTime;
    std::chrono::nanoseconds                    m_NextScheduleTime = 0ns;
    IO*                                         m_IO;
    bool                                        m_Enabled = false;
    bool                                        m_PhaseVisible = true;
    bool                                        m_Scheduled = false;
    void Fire();
    void Schedule();
    bool VisibleNow() const noexcept;
    std::chrono::nanoseconds NextFireAfter() const noexcept;
    Impl()
    {        
    }
};

BlinkScheduler::BlinkScheduler(std::function<void()> _on_blink,
                               std::chrono::milliseconds _blink_time,
                               IO& _io):
    I( std::make_shared<Impl>() )
{
    I->m_OnBlink = std::move(_on_blink );
    I->m_BlinkTime = _blink_time;
    I->m_IO = &_io;
        
    if( !I->m_OnBlink )
        throw std::invalid_argument("BlinkScheduler _on_blink can't be empty");
    if( I->m_BlinkTime <= 0ms )
        throw std::invalid_argument("BlinkScheduler _blink_time must be zero");
}

BlinkScheduler::~BlinkScheduler()
{
}

bool BlinkScheduler::Enabled() const noexcept
{
    return I->m_Enabled;
}

void BlinkScheduler::Enable( bool _enabled ) noexcept
{
    if( I->m_Enabled == _enabled )
        return;
    
    if( I->m_Enabled ) { // disable
        I->m_Enabled = false;
    }
    else { // enable
        I->m_Enabled = true;
        if( !I->m_Scheduled ) {
            I->m_PhaseVisible = I->VisibleNow();
            I->Schedule();
        }
    }
}

bool BlinkScheduler::Visible() const noexcept
{
    if( !I->m_Enabled )
        return true;
    
    return I->m_PhaseVisible;
}

void BlinkScheduler::Impl::Schedule()
{
    assert( m_Scheduled == false );
    assert( m_Enabled == true );
    
    const auto after = NextFireAfter();
    std::weak_ptr<Impl> impl = weak_from_this();
    m_IO->Dispatch(after, [impl]{
        if( auto me = impl.lock() )
            me->Fire();
    });
    m_Scheduled = true;
}

void BlinkScheduler::Impl::Fire()
{
    m_Scheduled = false;
    if( m_Enabled == false ) {
        // was disabled after scheduled - don't do anything
        return;
    }
    
    m_PhaseVisible = !m_PhaseVisible;
        
    m_OnBlink();
    
    if( m_Enabled == false ) {
        // now check for reentrancy shenenigans
        return;
    }

    Schedule();
}

std::chrono::nanoseconds BlinkScheduler::Impl::NextFireAfter() const noexcept
{
    const auto now = m_IO->Now();
    const auto div = std::chrono::duration_cast<std::chrono::milliseconds>( now ) / m_BlinkTime;
    return ((div + 1) * m_BlinkTime) - now;
}

bool BlinkScheduler::Impl::VisibleNow() const noexcept
{
    const auto now = m_IO->Now();
    auto n = std::chrono::duration_cast<std::chrono::milliseconds>( now ) / m_BlinkTime;
    return n % 2 == 0;
}

std::chrono::nanoseconds BlinkScheduler::DefaultIO::Now() noexcept
{
    return machtime();
}

void BlinkScheduler::DefaultIO::Dispatch(std::chrono::nanoseconds _after,
                  std::function<void()> _what) noexcept
{
    dispatch_to_main_queue_after( _after, std::move(_what) );
}

}
