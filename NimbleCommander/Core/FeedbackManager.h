#pragma once

class FeedbackManager
{
public:
    static FeedbackManager& Instance();
    
    
    /**
     * Decided if rating overlay need to be shown, based on usage statistics.
     * Can return true only once per run - assumes that this function is called only once per window.
     */
    bool ShouldShowRatingOverlayView();
    
    /**
     * 0: discard button was clicked (default).
     * [1-5]: amount of stars assigned.
     */
    void CommitRatingOverlayResult(int _result);
    
    /**
     * Will reset any information about application usage.
     */
    void ResetStatistics();
private:
    FeedbackManager();
    
    const int       m_ApplicationRunsCount;
    const double    m_TotalHoursUsed;
    const time_t    m_StartupTime;
    const time_t    m_FirstRunTime;
    bool            m_ShownRatingOverlay = false;
    
    optional<int>   m_LastRating; // 0 - discarded, [1-5] - rating
    optional<time_t>m_LastRatingTime;
};
