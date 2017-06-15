#pragma once

namespace nc::ops {

class Statistics
{

public:
    Statistics();
    ~Statistics();

    void StartTiming() noexcept;
    void PauseTiming() noexcept;
    void ResumeTiming() noexcept;
    void StopTiming() noexcept;
    
    nanoseconds ElapsedTime() const noexcept;
    
    void CommitProcessedBytes( uint64_t _bytes );
    
    

    struct StatPoint
    {
        float value;
        float fraction; // (0..1]
    };


    vector<StatPoint> BytesPerSecond() const;
    
    double BytesPerSecondSpeedDirect() const;
    double BytesPerSecondSpeedAverage() const;
    
private:

    atomic_bool m_IsTiming{false};
    atomic_int  m_PauseCount{0};
    nanoseconds m_StartTimePoint{0};
    nanoseconds m_PauseTimePoint{0};
    nanoseconds m_SleptTimeDuration{0};
    nanoseconds m_FinalTimeDuration{0};
    
    uint64_t    m_BytesProcessed{0};
    nanoseconds m_LastBytesCommitTimePoint{0};
    vector<StatPoint> m_BytesPerSecond;

    
};

}
