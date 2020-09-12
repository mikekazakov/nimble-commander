// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <chrono>
#include <Utility/FPSLimitedDrawer.h>

namespace nc::utility {

class BlinkScheduler
{
public:
    BlinkScheduler( id<ViewWithFPSLimitedDrawer> _view,
                  std::chrono::milliseconds _blink_time = std::chrono::milliseconds(600) );
    ~BlinkScheduler();

    bool Enabled() const;
    void SetEnabled( bool _enabled );
    
    bool Visible() const;
    
    void ScheduleNextRedraw();
    
private:
    const __weak id<ViewWithFPSLimitedDrawer>   m_View;
    const std::chrono::milliseconds             m_BlinkTime;
    std::chrono::nanoseconds                    m_NextScheduleTime;
    bool                                        m_Enabled = true;
};

}
