#include "Statistics.h"

namespace nc::ops {

Statistics::Statistics()
{
}

Statistics::~Statistics()
{
}

void Statistics::StartTiming() noexcept
{
    if( !m_IsTiming) {
        m_StartTimePoint = machtime();
        m_LastBytesCommitTimePoint = m_StartTimePoint;
        m_IsTiming = true;
    }
}

void Statistics::PauseTiming() noexcept
{
    if( !m_PauseCount )
        m_PauseTimePoint = machtime();
    m_PauseCount++;
}

void Statistics::ResumeTiming() noexcept
{
    m_PauseCount--;
    if( !m_PauseCount ) {
        const auto dt = machtime() - m_PauseTimePoint;
        m_SleptTimeDuration += dt;
        m_LastBytesCommitTimePoint += dt;
    }
}
    
void Statistics::StopTiming() noexcept
{
    if( m_IsTiming ) {
        if( m_PauseCount )
            m_FinalTimeDuration = m_PauseTimePoint - m_StartTimePoint - m_SleptTimeDuration;
        else
            m_FinalTimeDuration = machtime() - m_StartTimePoint - m_SleptTimeDuration;
        m_IsTiming = false;
    }
}

nanoseconds Statistics::ElapsedTime() const noexcept
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

void Statistics::CommitProcessedBytes( uint64_t _bytes )
{
    const auto current_time = machtime();
    const auto delta_time = current_time - m_LastBytesCommitTimePoint;
    m_BytesProcessed += _bytes;
    m_LastBytesCommitTimePoint = current_time;
    
    const auto fp_bytes = double(_bytes);
    const auto fp_delta_time = ((double)delta_time.count()) / 1000000000.;
    auto fp_left_delta_time = fp_delta_time;
    if( !m_BytesPerSecond.empty() && m_BytesPerSecond.back().fraction < 1. ) {
        auto &last = m_BytesPerSecond.back();
        const auto dt = min( 1. - last.fraction, fp_left_delta_time );
        const auto db = fp_bytes * dt / fp_delta_time;
        last.value += db;
        last.fraction += dt;
        fp_left_delta_time -= dt;
    }
    
    while( fp_left_delta_time > 0. ) {
        const auto dt = min( 1., fp_left_delta_time );
        const auto db = fp_bytes * dt / fp_delta_time;
        fp_left_delta_time -= dt;
        StatPoint sp;
        sp.value = db;
        sp.fraction = dt;
        m_BytesPerSecond.emplace_back( sp );
    }
}

vector<Statistics::StatPoint> Statistics::BytesPerSecond() const
{
    return m_BytesPerSecond;
}

double Statistics::BytesPerSecondSpeedDirect() const
{
    return double(m_BytesProcessed) /
           (double((m_LastBytesCommitTimePoint - m_StartTimePoint - m_SleptTimeDuration).count()) /
            1000000000.);
}

double Statistics::BytesPerSecondSpeedAverage() const
{
    double bps = 0;
    int n = 0;
    for( auto &v: m_BytesPerSecond )
        if( v.fraction >= 0.5 ) {
            bps += (v.value / v.fraction);
            n++;
        }
    bps /= n;
    return bps;
}

}
