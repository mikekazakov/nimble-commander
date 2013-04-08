//
//  TimedDummyOperationJob.cpp
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "TimedDummyOperationJob.h"

#import "TimedDummyOperation.h"

#import "OperationDialogAlert.h"

TimedDummyOperationJob::TimedDummyOperationJob()
:   m_CompleteTime(1),
    m_Operation(nil)
{
    
}

void TimedDummyOperationJob::Init(TimedDummyOperation *_op, int _seconds)
{
    m_Operation = _op;
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
        
        if (rand()%100 == 0)
        {
            if (false)
            {
                TimedDummyOperationTestDialog *dialog = [m_Operation AskUser:elapsed_time];
            
                if ([dialog WaitForResult] == OperationDialogResult::Stop)
                {
                    SetStopped();
                    return;
                }
            
                if (dialog.NewTime != -1)
                    elapsed_time = dialog.NewTime;
            }
            else
            {
                OperationDialogAlert *alert = [m_Operation AskUserAlert];
                if ([alert WaitForResult] == OperationDialogResult::Stop)
                {
                    SetStopped();
                    return;
                }
            
                if (alert.Result == OperationDialogResult::Custom)
                    elapsed_time = 0;
            }
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