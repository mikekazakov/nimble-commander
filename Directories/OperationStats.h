//
//  OperationStats.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <mach/mach_time.h>

class OperationStats
{
public:
    OperationStats();
    
    void SetMaxValue(uint64_t _max_value);
    uint64_t GetMaxValue() const;
    
    void SetValue(uint64_t _value);
    void AddValue(uint64_t _value);
    uint64_t GetValue() const;
    
    // Retruns value in range from 0 to 1. Equals to current value divided by max value.
    float GetProgress() const;
    
    void SetCurrentItem(const char *_item);
    const char *GetCurrentItem() const;
    // Return true if item was changed after the previous call to IsCurrentItemChanged.
    // Clears changed status when called.
    bool IsCurrentItemChanged();
    
    void StartTimeTracking();
    // Pauses the time tracking. Keeps track of how many times it was invoked.
    // To resume tracking, ResumeTimeTracking must be called the same number of times.
    void PauseTimeTracking();
    void ResumeTimeTracking();

    // Returns time in milliseconds.
    int GetTime() const;
    
private:
    volatile uint64_t m_StartTime;
    volatile uint64_t m_PauseTime;
    
    volatile bool m_Started;
    volatile int m_Paused;
    
    const char *m_CurrentItem;
    volatile bool m_CurrentItemChanged;
    volatile uint64_t m_Value;
    volatile uint64_t m_MaxValue;
    
    mutable pthread_mutex_t m_Mutex;
    
    static mach_timebase_info_data_t m_TimeInfo;
    static bool m_TimeInfoInited;
};