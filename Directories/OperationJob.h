//
//  OperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#ifndef Directories_OperationJob_h
#define Directories_OperationJob_h

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
    
    // Returns value in range from 0 to 1.
    // TODO: remove, refactor, ....
    float GetProgress() const;
    
    bool IsFinished() const;
    bool IsPaused() const;
    
    State GetState() const;
    
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
    
    // Sets the current progress of the job. Value must be in [0..1] range.
    // TODO: remove, refactor, ...
    void SetProgress(float _progress);
    
private:
    // Current state of the job.
    volatile State m_State;
    
    // Indicates that internal thread should pause execution.
    // Internal thread only reads this variable.
    volatile bool m_Paused;
    
    // Requests internal thread to stop execution.
    // Internal thread only reads this variable.
    volatile bool m_RequestStop;
    
    float m_Progress;
    
    // Disable copy constructor and operator.
    OperationJob(const OperationJob&);
    const OperationJob& operator=(const OperationJob&);
};

#endif
