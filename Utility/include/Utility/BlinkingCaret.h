// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <chrono>
#include <Utility/FPSLimitedDrawer.h>

class BlinkingCaret
{
public:
    BlinkingCaret( id<ViewWithFPSLimitedDrawer> _view, std::chrono::milliseconds _blink_time = std::chrono::milliseconds(600) );
    ~BlinkingCaret();

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
