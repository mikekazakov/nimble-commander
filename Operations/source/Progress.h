// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

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
    optional<nanoseconds> ETA() const noexcept;    
    
    void CommitEstimated( uint64_t _volume_delta );
    void CommitProcessed( uint64_t _volume_delta );
    void CommitSkipped( uint64_t _volume_delta );

    void SetupTiming();
    void ReportSleptDelta( nanoseconds _time_delta );
    
    const vector<TimePoint>& Data() const;
    
public:
    atomic_ulong        m_Estimated;
    atomic_ulong        m_Processed;
    nanoseconds         m_BaseTimePoint;
    nanoseconds         m_LastCommitTimePoint;
    mutable spinlock    m_TimepointsLock;
    vector<TimePoint>   m_Timeline;
};

}
