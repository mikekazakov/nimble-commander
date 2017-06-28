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
    double                      DoneFraction( SourceType _type ) const noexcept;
    optional<nanoseconds>       ETA( SourceType _type ) const noexcept;
    uint64_t                    VolumeTotal( SourceType _type ) const noexcept;
    uint64_t                    VolumeProcessed( SourceType _type ) const noexcept;
    double                      SpeedPerSecondDirect( SourceType _type ) const;
    double                      SpeedPerSecondAverage( SourceType _type ) const;
    vector<Progress::TimePoint> BytesPerSecond() const;
   
    void CommitEstimated( SourceType _type, uint64_t _delta );
    void CommitProcessed( SourceType _type, uint64_t _delta );
    
    // + CommitSkipped
    
private:
    Progress &Timeline(SourceType _type) noexcept;
    const Progress &Timeline(SourceType _type) const noexcept;

    atomic_bool m_IsTiming{false};
    atomic_int  m_PauseCount{0};
    nanoseconds m_StartTimePoint{0};
    nanoseconds m_PauseTimePoint{0};
    nanoseconds m_SleptTimeDuration{0};
    nanoseconds m_FinalTimeDuration{0};
    
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
