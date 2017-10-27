// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Statistics.h"

namespace nc::ops {

StatisticsTimingPauser::StatisticsTimingPauser( Statistics &_s ):
    s(_s)
{
    s.PauseTiming();
}

StatisticsTimingPauser::~StatisticsTimingPauser()
{
    s.ResumeTiming();
}

Statistics::Statistics():
    m_IsTiming{false},
    m_PauseCount{0},
    m_StartTimePoint{0},
    m_PauseTimePoint{0},
    m_SleptTimeDuration{0},
    m_FinalTimeDuration{0},
    m_PreferredSource{SourceType::Bytes}
{
}

Statistics::~Statistics()
{
}

void Statistics::StartTiming() noexcept
{
    if( !m_IsTiming) {
        m_StartTimePoint = machtime();
        m_BytesTimeline.SetupTiming();
        m_ItemsTimeline.SetupTiming();
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
        m_BytesTimeline.ReportSleptDelta(dt);
        m_ItemsTimeline.ReportSleptDelta(dt);
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

void Statistics::CommitEstimated( SourceType _type, uint64_t _delta )
{
    Timeline(_type).CommitEstimated(_delta);
}

void Statistics::CommitProcessed( SourceType _type, uint64_t _delta )
{
    Timeline(_type).CommitProcessed(_delta);
}

void Statistics::CommitSkipped( SourceType _type, uint64_t _delta )
{
    Timeline(_type).CommitSkipped(_delta);
}

vector<Progress::TimePoint> Statistics::BytesPerSecond() const
{
    return m_BytesTimeline.Data();
}

double Statistics::SpeedPerSecondDirect(SourceType _type) const
{
    return Timeline(_type).VolumePerSecondDirect();
}

double Statistics::SpeedPerSecondAverage(SourceType _type) const
{
    return Timeline(_type).VolumePerSecondAverage();
}

optional<nanoseconds> Statistics::ETA(SourceType _type) const noexcept
{
    return Timeline(_type).ETA();
}

double Statistics::DoneFraction(SourceType _type) const noexcept
{
    return Timeline(_type).DoneFraction();
}

Progress &Statistics::Timeline(SourceType _type) noexcept
{
    if( _type == SourceType::Bytes )
        return m_BytesTimeline;
    else
        return m_ItemsTimeline;
}

const Progress &Statistics::Timeline(SourceType _type) const noexcept
{
    if( _type == SourceType::Bytes )
        return m_BytesTimeline;
    else
        return m_ItemsTimeline;
}

uint64_t Statistics::VolumeTotal( SourceType _type ) const noexcept
{
    return Timeline(_type).VolumeTotal();
}

uint64_t Statistics::VolumeProcessed( SourceType _type ) const noexcept
{
    return Timeline(_type).VolumeProcessed();
}

bool Statistics::IsPaused() const noexcept
{
    return m_PauseCount > 0;
}

Statistics::SourceType Statistics::PreferredSource() const noexcept
{
    return m_PreferredSource;
}

void Statistics::SetPreferredSource( SourceType _type )
{
    m_PreferredSource = _type;
}

}
