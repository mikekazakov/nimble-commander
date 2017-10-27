// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Progress.h"

namespace nc::ops {

Progress::Progress():
    m_Estimated{0},
    m_Processed{0},
    m_LastCommitTimePoint{0},
    m_BaseTimePoint{0}
{
}

Progress::~Progress()
{
}

void Progress::CommitEstimated( uint64_t _delta )
{
    m_Estimated += _delta;
}

void Progress::CommitSkipped( uint64_t _delta )
{
    if( _delta + m_Processed > m_Estimated ) {
        cerr << "Progress::CommitSkipped: supicious argument: "
            "_delta + m_Processed > m_Estimated" << endl;
        m_Estimated = m_Processed.load();
    }
    else {
        m_Estimated -= _delta;
    }
}

void Progress::CommitProcessed( uint64_t _delta )
{
    const auto current_time = machtime();
    m_TimepointsLock.lock();
    const auto delta_time = current_time - m_LastCommitTimePoint;
    m_LastCommitTimePoint = current_time;
    m_Processed += _delta;
    m_TimepointsLock.unlock();
    
    const auto fp_bytes = double(_delta);
    const auto fp_delta_time = ((double)delta_time.count()) / 1000000000.;
    auto fp_left_delta_time = fp_delta_time;
    if( !m_Timeline.empty() && m_Timeline.back().fraction < 1. ) {
        auto &last = m_Timeline.back();
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
        TimePoint sp;
        sp.value = db;
        sp.fraction = dt;
        m_Timeline.emplace_back( sp );
    }
}

void Progress::ReportSleptDelta( nanoseconds _delta )
{
    LOCK_GUARD(m_TimepointsLock) {
        m_LastCommitTimePoint += _delta;
        m_BaseTimePoint += _delta;
    }
}

void Progress::SetupTiming()
{
    LOCK_GUARD(m_TimepointsLock) {
        m_BaseTimePoint = machtime();
        m_LastCommitTimePoint = m_BaseTimePoint;
    }
}

double Progress::VolumePerSecondDirect() const noexcept
{
    if( m_Processed == 0 )
        return 0.;
    LOCK_GUARD(m_TimepointsLock) {
        const auto dt = m_LastCommitTimePoint - m_BaseTimePoint;
        if( dt.count() == 0 )
            return 0;
        return double(m_Processed) / (double(dt.count()) / 1000000000.);
    }
}

double Progress::VolumePerSecondAverage() const noexcept
{
    const auto min_fraction = 0.5;
    double vps = 0;
    int n = 0;
    for( auto &v: m_Timeline )
        if( v.fraction >= min_fraction ) {
            vps += (v.value / v.fraction);
            n++;
        }
    if( !n )
        return 0.;
    vps /= n;
    return vps;
}

double Progress::DoneFraction() const noexcept
{
    if( m_Estimated == 0 || m_Processed == 0 )
        return 0.;
    return double(m_Processed) / (double)m_Estimated;
}

optional<nanoseconds> Progress::ETA() const noexcept
{
    const auto speed = VolumePerSecondDirect();
    if( speed == 0. )
        return nullopt;
    if( m_Processed >= m_Estimated )
        return 0ns;
    const auto left = double(m_Estimated - m_Processed);
    const auto eta = left / double(speed);
    return nanoseconds{(long long)(eta*1000000000.)};
}

const vector<Progress::TimePoint>& Progress::Data() const
{
    return m_Timeline;
}

uint64_t Progress::VolumeTotal() const noexcept
{
    return m_Estimated;
}

uint64_t Progress::VolumeProcessed() const noexcept
{
    return m_Processed;
}

}
