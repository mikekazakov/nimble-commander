//
//  OperationStats.m
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationStats.h"
#import <pthread.h>

mach_timebase_info_data_t OperationStats::m_TimeInfo;
bool OperationStats::m_TimeInfoInited = false;

OperationStats::OperationStats()
:   m_StartTime(0),
    m_PauseTime(0),
    m_Started(false),
    m_Paused(0),
    m_CurrentItem(nullptr),
    m_Value(0),
    m_MaxValue(1)
{
    if (!m_TimeInfoInited)
    {
        m_TimeInfoInited = true;
        mach_timebase_info(&m_TimeInfo);
    }
    
    pthread_mutex_init(&m_Mutex, nullptr);
}

void OperationStats::SetMaxValue(uint64_t _max_value)
{
    assert(_max_value);
    assert(m_Value <= _max_value);
    
    m_MaxValue = _max_value;
}

uint64_t OperationStats::GetMaxValue() const
{
    return m_MaxValue;
}

void OperationStats::SetValue(uint64_t _value)
{
    m_Value = _value;
    assert(m_Value <= m_MaxValue);
}

void OperationStats::AddValue(uint64_t _value)
{
    m_Value += _value;
    assert(m_Value <= m_MaxValue);
}

uint64_t OperationStats::GetValue() const
{
    return m_Value;
}

float OperationStats::GetProgress() const
{
    return (float)m_Value/m_MaxValue;
}

void OperationStats::SetCurrentItem(const char *_item)
{
    m_CurrentItem = _item;
}

const char *OperationStats::GetCurrentItem() const
{
    return m_CurrentItem;
}

void OperationStats::StartTimeTracking()
{
    pthread_mutex_lock(&m_Mutex);
    
    assert(!m_Started);
    
    m_StartTime = mach_absolute_time();
    
    if (m_Paused) m_PauseTime = m_StartTime;
    
    m_Started = true;
    
    pthread_mutex_unlock(&m_Mutex);
}

void OperationStats::PauseTimeTracking()
{
    pthread_mutex_lock(&m_Mutex);
    
    if (++m_Paused == 1)
        m_PauseTime = mach_absolute_time();

    pthread_mutex_unlock(&m_Mutex);
}

void OperationStats::ResumeTimeTracking()
{
    pthread_mutex_lock(&m_Mutex);
    
    assert(m_Paused >= 1);
    if (--m_Paused == 0)
    {
        uint64_t pause_duration = mach_absolute_time() - m_PauseTime;
        m_StartTime += pause_duration;
    }
    
    pthread_mutex_unlock(&m_Mutex);
}

uint64_t OperationStats::GetTime() const
{
    pthread_mutex_lock(&m_Mutex);
    
    uint64_t time;
    
    if (!m_Started)
        time = 0;
    else if (m_Paused)
        time = m_PauseTime - m_StartTime;
    else
        time = mach_absolute_time() - m_StartTime;
 
    pthread_mutex_unlock(&m_Mutex);
    
    return time * m_TimeInfo.numer/m_TimeInfo.denom;
}
