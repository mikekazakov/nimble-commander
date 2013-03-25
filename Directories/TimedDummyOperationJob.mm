//
//  TimedDummyOperationJob.cpp
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "TimedDummyOperationJob.h"

TimedDummyOperationJob::TimedDummyOperationJob()
:   m_CompleteTime(1)
{
    
}

void TimedDummyOperationJob::Init(int _seconds)
{
    m_CompleteTime = _seconds*1000;
}

void TimedDummyOperationJob::Do()
{
    int elapsed_time = 0;
    
    for(;;)
    {
        if (CheckPauseOrStop(100))
        {
            SetStopped();
            return;
        }
        
        int delay = 33;
        
        usleep(1000*delay);
        
        elapsed_time += delay;
        
        SetProgress((float)elapsed_time/m_CompleteTime);
        
        if (elapsed_time >= m_CompleteTime)
        {
            SetCompleted();
            return;
        }
    }
}