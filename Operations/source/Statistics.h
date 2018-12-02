// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
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
    
    std::chrono::nanoseconds    ElapsedTime() const noexcept;
    SourceType                  PreferredSource() const noexcept;
    void                        SetPreferredSource( SourceType _type );
    
    double                              DoneFraction( SourceType _type ) const noexcept;
    std::optional<std::chrono::nanoseconds> ETA( SourceType _type ) const noexcept;
    uint64_t                            VolumeTotal( SourceType _type ) const noexcept;
    uint64_t                            VolumeProcessed( SourceType _type ) const noexcept;
    double                              SpeedPerSecondDirect( SourceType _type ) const;
    double                              SpeedPerSecondAverage( SourceType _type ) const;
    std::vector<Progress::TimePoint>    BytesPerSecond() const;
   
    void CommitEstimated( SourceType _type, uint64_t _delta );
    void CommitProcessed( SourceType _type, uint64_t _delta );
    void CommitSkipped( SourceType _type, uint64_t _delta );
    
private:
    Progress &Timeline(SourceType _type) noexcept;
    const Progress &Timeline(SourceType _type) const noexcept;

    std::atomic_bool m_IsTiming;
    std::atomic_int  m_PauseCount;
    std::chrono::nanoseconds m_StartTimePoint;
    std::chrono::nanoseconds m_PauseTimePoint;
    std::chrono::nanoseconds m_SleptTimeDuration;
    std::chrono::nanoseconds m_FinalTimeDuration;
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
