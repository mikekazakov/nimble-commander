// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Progress.h"
#include <iostream>
#include <Base/mach_time.h>

namespace nc::ops {

Progress::Progress() : m_Estimated{0}, m_Processed{0}, m_BaseTimePoint{0}, m_LastCommitTimePoint{0}
{
}

Progress::~Progress() = default;

void Progress::CommitEstimated(uint64_t _delta)
{
    m_Estimated += _delta;
}

void Progress::CommitSkipped(uint64_t _delta)
{
    if( _delta + m_Processed > m_Estimated ) {
        std::cerr << "Progress::CommitSkipped: supicious argument: "
                     "_delta + m_Processed > m_Estimated"
                  << std::endl;
        m_Estimated = m_Processed.load();
    }
    else {
        m_Estimated -= _delta;
    }
}

void Progress::CommitProcessed(uint64_t _delta)
{
    const auto current_time = base::machtime();
    m_TimepointsLock.lock();
    const auto delta_time = current_time - m_LastCommitTimePoint;
    m_LastCommitTimePoint = current_time;
    m_Processed += _delta;
    m_TimepointsLock.unlock();

    const auto fp_bytes = double(_delta);
    const auto fp_delta_time = static_cast<double>(delta_time.count()) / 1000000000.;
    auto fp_left_delta_time = fp_delta_time;
    if( !m_Timeline.empty() && m_Timeline.back().fraction < 1. ) {
        auto &last = m_Timeline.back();
        const auto dt = std::min(1. - last.fraction, fp_left_delta_time);
        const auto db = fp_bytes * dt / fp_delta_time;
        last.value = static_cast<float>(last.value + db);
        last.fraction = static_cast<float>(last.fraction + dt);
        fp_left_delta_time -= dt;
    }

    while( fp_left_delta_time > 0. ) {
        const auto dt = std::min(1., fp_left_delta_time);
        const auto db = fp_bytes * dt / fp_delta_time;
        fp_left_delta_time -= dt;
        TimePoint sp;
        sp.value = static_cast<float>(db);
        sp.fraction = static_cast<float>(dt);
        m_Timeline.emplace_back(sp);
    }
}

void Progress::ReportSleptDelta(std::chrono::nanoseconds _delta)
{
    auto lock = std::lock_guard{m_TimepointsLock};
    m_LastCommitTimePoint += _delta;
    m_BaseTimePoint += _delta;
}

void Progress::SetupTiming()
{
    auto lock = std::lock_guard{m_TimepointsLock};
    m_BaseTimePoint = base::machtime();
    m_LastCommitTimePoint = m_BaseTimePoint;
}

double Progress::VolumePerSecondDirect() const noexcept
{
    if( m_Processed == 0 )
        return 0.;
    auto lock = std::lock_guard{m_TimepointsLock};
    const auto dt = m_LastCommitTimePoint - m_BaseTimePoint;
    if( dt.count() == 0 )
        return 0;
    return double(m_Processed) / (double(dt.count()) / 1000000000.);
}

double Progress::VolumePerSecondAverage() const noexcept
{
    const auto min_fraction = 0.5;
    double vps = 0;
    int n = 0;
    for( auto &v : m_Timeline )
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
    return double(m_Processed) / double(m_Estimated);
}

std::optional<std::chrono::nanoseconds> Progress::ETA() const noexcept
{
    using namespace std::literals;
    const auto speed = VolumePerSecondDirect();
    if( speed == 0. )
        return std::nullopt;
    if( m_Processed >= m_Estimated )
        return 0ns;
    const auto left = double(m_Estimated - m_Processed);
    const auto eta = left / double(speed);
    return std::chrono::nanoseconds{static_cast<long long>(eta * 1000000000.)};
}

const std::vector<Progress::TimePoint> &Progress::Data() const
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

} // namespace nc::ops
