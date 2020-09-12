// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.

#include "../include/Utility/BlinkScheduler.h"
#include <Habanero/mach_time.h>
#include <Habanero/dispatch_cpp.h>
#include <stdexcept>

namespace nc::utility {

using namespace std::chrono_literals;

BlinkScheduler::BlinkScheduler( id<ViewWithFPSLimitedDrawer> _view,
                             std::chrono::milliseconds _blink_time ):
    m_View( _view ),
    m_BlinkTime( _blink_time ),
    m_NextScheduleTime( 0 )
{
    if( !_view )
        throw std::logic_error("BlinkingCaret::BlinkingCaret _view can't be nil");
    if( _blink_time == 0ms )
        throw std::logic_error("BlinkingCaret::BlinkingCaret _blink_time can't be zero");
}

BlinkScheduler::~BlinkScheduler()
{
}

bool BlinkScheduler::Enabled() const
{
    return m_Enabled;
}

void BlinkScheduler::SetEnabled( bool _enabled )
{
    m_Enabled = _enabled;
}

bool BlinkScheduler::Visible() const
{
    if( !m_Enabled )
        return true;
    
    auto n = std::chrono::duration_cast<std::chrono::milliseconds>(machtime()) / m_BlinkTime;
    return n % 2 == 0;
}

void BlinkScheduler::ScheduleNextRedraw()
{
    if( !m_Enabled )
        return;
    
    auto mt = machtime();
    
    if( mt < m_NextScheduleTime )
        return;
    
    __weak id<ViewWithFPSLimitedDrawer> view = m_View;
    dispatch_to_main_queue_after( m_BlinkTime, [=]{
        if( id<ViewWithFPSLimitedDrawer> v = view )
            [v.fpsDrawer invalidate];
    });
    m_NextScheduleTime = mt + m_BlinkTime;
}

}
