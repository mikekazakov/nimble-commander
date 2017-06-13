#include "Statistics.h"

namespace nc::ops {

Statistics::Statistics()
{
}

Statistics::~Statistics()
{
}

void Statistics::StartTiming()
{
    if( !m_IsTiming) {
        m_StartTimePoint = machtime();
        m_IsTiming = true;
    }
}

void Statistics::PauseTiming()
{
    if( !m_PauseCount )
        m_PauseTimePoint = machtime();
    m_PauseCount++;
}

void Statistics::ResumeTiming()
{
    m_PauseCount--;
    if( !m_PauseCount )
        m_SleptTimeDuration = machtime() - m_PauseTimePoint;
}
    
void Statistics::StopTiming()
{
    if( m_IsTiming ) {
        if( m_PauseCount )
            m_FinalTimeDuration = m_PauseTimePoint - m_StartTimePoint - m_SleptTimeDuration;
        else
            m_FinalTimeDuration = machtime() - m_StartTimePoint - m_SleptTimeDuration;
        m_IsTiming = false;
    }
}

nanoseconds Statistics::ElapsedTime() const
{
    if( m_IsTiming ) {
        if( m_PauseCount )
            return m_PauseTimePoint - m_StartTimePoint - m_SleptTimeDuration;
        else
            return machtime() - m_StartTimePoint - m_SleptTimeDuration;
    }
    else {
        return m_FinalTimeDuration;
    }
}

}
