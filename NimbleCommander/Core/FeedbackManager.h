// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <time.h>

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
     * Amount of time application was started, updated on every startup.
     */
    int ApplicationRunsCount() const noexcept;
    
    /**
     * Will reset any information about application usage.
     */
    void ResetStatistics();
    
    void EmailFeedback();
    void EmailSupport();
    void RateOnAppStore();
    void ShareOnFacebook();
    void ShareOnTwitter();
    void ShareOnLinkedIn();
private:
    FeedbackManager();
    bool IsEligibleForRatingOverlay() const;
    
    const int       m_ApplicationRunsCount;
    const double    m_TotalHoursUsed;
    const time_t    m_StartupTime;
    const time_t    m_FirstRunTime;
    bool            m_ShownRatingOverlay = false;
    
    std::optional<int>   m_LastRating; // 0 - discarded, [1-5] - rating
    std::optional<time_t>m_LastRatingTime;
};
