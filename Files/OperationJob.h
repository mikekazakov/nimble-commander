//
//  OperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#ifndef Directories_OperationJob_h
#define Directories_OperationJob_h

#import "OperationStats.h"

@class Operation;

class OperationJob
{
public:
    enum State
    {
        StateReady,
        StateRunning,
        StateStopped,
        StateCompleted,
        
        StatesCount
    };
    
    OperationJob();
    virtual ~OperationJob();
    
    void Start();
    void Pause();
    void Resume();
    void RequestStop();
    
    bool IsFinished() const;
    bool IsPaused() const;
    bool IsStopRequested() const;
    
    State GetState() const;
    
    OperationStats& GetStats();
    
    void SetBaseOperation(Operation *_op); // should be called only by Operation class
    
protected:
    virtual void Do() = 0;
    
    // Puts job in stopped state. Should be called just before exiting from the internal thread.
    void SetStopped();
    // Puts job in completed state. Should be called just before exiting from the internal thread.
    void SetCompleted();
    
    // Helper function that does 2 things:
    // - if m_Pause is true, it waits for m_Pause to become false, checking the value each
    //   _sleep_in_ms milliseconds
    // - if m_RequestStop is true, it returns true as soon as possible.
    // Typical usage in Do method:
    // if (CheckPauseOrStop())
    // {
    //      SetStopped();
    //      return;
    // }
    bool CheckPauseOrStop(int _sleep_in_ms = 100);
    
    OperationStats m_Stats;
    
private:
    // Current state of the job.
    volatile State m_State;
    
    // Indicates that internal thread should pause execution.
    // Internal thread only reads this variable.
    volatile bool m_Paused;
    
    // Requests internal thread to stop execution.
    // Internal thread only reads this variable.
    volatile bool m_RequestStop;
    
    __weak Operation *m_BaseOperation;
    
    // Disable copy constructor and operator.
    OperationJob(const OperationJob&) = delete;
    const OperationJob& operator=(const OperationJob&) = delete;
};

#endif
