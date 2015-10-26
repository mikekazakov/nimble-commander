//
//  OperationStats.m
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationStats.h"
#import "Common.h"

OperationStats::OperationStats()
{
}

OperationStats::~OperationStats()
{
}

void OperationStats::SetMaxValue(uint64_t _max_value)
{
    if(m_Value > _max_value)
        throw logic_error("OperationStats::SetMaxValue _max_value is less than current m_Value");
    
    m_MaxValue = _max_value;
}

uint64_t OperationStats::GetMaxValue() const
{
    return m_MaxValue;
}

void OperationStats::SetValue(uint64_t _value)
{
    if(_value > m_MaxValue)
        throw logic_error("OperationStats::SetValue _value is greater than m_MaxValue");

    NotifyWillChange(Nofity::Value);
    m_Value = _value;
    NotifyDidChange(Nofity::Value);
}

void OperationStats::AddValue(uint64_t _value)
{
    if(m_Value + _value > m_MaxValue)
        throw logic_error("OperationStats::AddValue resulting value is greater than m_MaxValue");
    
    NotifyWillChange(Nofity::Value);
    m_Value += _value;
    NotifyDidChange(Nofity::Value);
}

uint64_t OperationStats::GetValue() const noexcept
{
    return m_Value;
}

uint64_t OperationStats::RemainingValue() const noexcept
{
    return GetMaxValue() - GetValue();
}

double OperationStats::GetProgress() const noexcept
{
    return m_MaxValue != 0 ? (double)m_Value/(double)m_MaxValue : 0.;
}

void OperationStats::SetCurrentItem(string _item)
{
    lock_guard<mutex> lock(m_Lock);
    if( *m_CurrentItem != _item ) {
        m_CurrentItem = make_shared<string>(move(_item));
        if( m_OnCurrentItemChanged )
            dispatch_to_main_queue( m_OnCurrentItemChanged );
    }
}

shared_ptr<const string> OperationStats::GetCurrentItem() const
{
    lock_guard<mutex> lock(m_Lock);
    return m_CurrentItem;
}

void OperationStats::SetOnCurrentItemChanged(function<void()> _callback)
{
    lock_guard<mutex> lock(m_Lock);
    m_OnCurrentItemChanged = move(_callback);
}

void OperationStats::StartTimeTracking()
{
    if(m_Started)
        return;
    lock_guard<mutex> lock(m_Lock);
    m_StartTime = machtime();
    if (m_Paused)
        m_PauseTime = m_StartTime;
    m_Started = true;
}

void OperationStats::PauseTimeTracking()
{
    lock_guard<mutex> lock(m_Lock);
    if (++m_Paused == 1)
        m_PauseTime = machtime();
}

void OperationStats::ResumeTimeTracking()
{
    lock_guard<mutex> lock(m_Lock);
    if(m_Paused == 0)
        return;
    if (--m_Paused == 0) {
        auto pause_duration = machtime() - m_PauseTime;
        m_StartTime += pause_duration;
    }
}

milliseconds OperationStats::GetTime() const
{
    lock_guard<mutex> lock(m_Lock);
    nanoseconds time;
    if (!m_Started)
        time = 0ns;
    else if (m_Paused)
        time = m_PauseTime - m_StartTime;
    else
        time = machtime() - m_StartTime;

    return duration_cast<milliseconds>(time);
}
