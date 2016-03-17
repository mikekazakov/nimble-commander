//
//  BlinkingCaret.h
//  Files
//
//  Created by Michael G. Kazakov on 23/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once


#include <Utility/FPSLimitedDrawer.h>

class BlinkingCaret
{
public:
    BlinkingCaret( id<ViewWithFPSLimitedDrawer> _view, milliseconds _blink_time = 600ms );
    ~BlinkingCaret();

    bool Enabled() const;
    void SetEnabled( bool _enabled );
    
    bool Visible() const;
    
    void ScheduleNextRedraw();
    
private:
    const __weak id<ViewWithFPSLimitedDrawer>   m_View;
    const milliseconds                          m_BlinkTime;
    nanoseconds                                 m_NextScheduleTime;
    bool                                        m_Enabled = true;
};
