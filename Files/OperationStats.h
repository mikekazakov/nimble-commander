//
//  OperationStats.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

class OperationStats
{
public:
    OperationStats();
    ~OperationStats();
    
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

    /**
     * Returns worked time in milliseconds.
     */
    milliseconds GetTime() const;
    
private:
    nanoseconds m_StartTime{0};
    nanoseconds m_PauseTime{0};
    
    volatile bool m_Started = false;
    volatile int m_Paused = false;
    
    const char *m_CurrentItem = nullptr;
    volatile bool m_CurrentItemChanged = false;
    volatile uint64_t m_Value = 0;
    volatile uint64_t m_MaxValue = 1;
    mutable mutex     m_Lock;
    
    OperationStats(const OperationStats&) = delete;
    void operator=(const OperationStats&) = delete;
};
