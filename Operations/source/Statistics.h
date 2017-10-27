// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Progress.h"

namespace nc::ops {

class Statistics
{
public:
    enum class SourceType {
        Bytes,
        Items
    };
 
    Statistics();
    ~Statistics();

    void StartTiming()  noexcept;
    void PauseTiming()  noexcept;
    void ResumeTiming() noexcept;
    void StopTiming()   noexcept;
    
    bool IsPaused() const noexcept;
    
    nanoseconds                 ElapsedTime() const noexcept;
    SourceType                  PreferredSource() const noexcept;
    void                        SetPreferredSource( SourceType _type );
    
    double                      DoneFraction( SourceType _type ) const noexcept;
    optional<nanoseconds>       ETA( SourceType _type ) const noexcept;
    uint64_t                    VolumeTotal( SourceType _type ) const noexcept;
    uint64_t                    VolumeProcessed( SourceType _type ) const noexcept;
    double                      SpeedPerSecondDirect( SourceType _type ) const;
    double                      SpeedPerSecondAverage( SourceType _type ) const;
    vector<Progress::TimePoint> BytesPerSecond() const;
   
    void CommitEstimated( SourceType _type, uint64_t _delta );
    void CommitProcessed( SourceType _type, uint64_t _delta );
    void CommitSkipped( SourceType _type, uint64_t _delta );
    
private:
    Progress &Timeline(SourceType _type) noexcept;
    const Progress &Timeline(SourceType _type) const noexcept;

    atomic_bool m_IsTiming;
    atomic_int  m_PauseCount;
    nanoseconds m_StartTimePoint;
    nanoseconds m_PauseTimePoint;
    nanoseconds m_SleptTimeDuration;
    nanoseconds m_FinalTimeDuration;
    SourceType m_PreferredSource;
    
    Progress m_BytesTimeline;
    Progress m_ItemsTimeline;
};

struct StatisticsTimingPauser
{
    StatisticsTimingPauser( Statistics &_s );
    ~StatisticsTimingPauser();
private:
    Statistics &s;
};

}
