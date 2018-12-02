// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <optional>
#include <chrono>
#include <vector>
#include <Habanero/spinlock.h>

namespace nc::ops {

class Progress
{
public:
    Progress();
    ~Progress();

    struct TimePoint
    {
        float value;
        float fraction; // (0..1]
    };

    double VolumePerSecondDirect() const noexcept;
    double VolumePerSecondAverage() const noexcept;
    
    uint64_t VolumeTotal() const noexcept;
    uint64_t VolumeProcessed() const noexcept;
    double DoneFraction() const noexcept;
    std::optional<std::chrono::nanoseconds> ETA() const noexcept;
    
    void CommitEstimated( uint64_t _volume_delta );
    void CommitProcessed( uint64_t _volume_delta );
    void CommitSkipped( uint64_t _volume_delta );

    void SetupTiming();
    void ReportSleptDelta( std::chrono::nanoseconds _time_delta );
    
    const std::vector<TimePoint>& Data() const;
    
public:
    std::atomic_ulong        m_Estimated;
    std::atomic_ulong        m_Processed;
    std::chrono::nanoseconds m_BaseTimePoint;
    std::chrono::nanoseconds m_LastCommitTimePoint;
    mutable spinlock    m_TimepointsLock;
    std::vector<TimePoint>   m_Timeline;
};

}
