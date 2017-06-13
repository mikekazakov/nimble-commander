#pragma once

namespace nc::ops {

class Statistics
{

public:
    Statistics();
    ~Statistics();

    void StartTiming();
    void PauseTiming();
    void ResumeTiming();
    void StopTiming();
    
    nanoseconds ElapsedTime() const;
    
private:
    atomic_bool m_IsTiming{false};
    atomic_int  m_PauseCount{0};
    nanoseconds m_StartTimePoint{0};
    nanoseconds m_PauseTimePoint{0};
    nanoseconds m_SleptTimeDuration{0};
    nanoseconds m_FinalTimeDuration{0};
};

}
