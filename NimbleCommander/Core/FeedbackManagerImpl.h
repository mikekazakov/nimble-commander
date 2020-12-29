// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "FeedbackManager.h"
#include <optional>
#include <time.h>

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc {

class FeedbackManagerImpl : public FeedbackManager
{
public:
    FeedbackManagerImpl(nc::bootstrap::ActivationManager &_am);
    
    /**
     * Decided if rating overlay need to be shown, based on usage statistics.
     * Can return true only once per run - assumes that this function is called only once per
     * window.
     */
    bool ShouldShowRatingOverlayView() override;

    /**
     * 0: discard button was clicked (default).
     * [1-5]: amount of stars assigned.
     */
    void CommitRatingOverlayResult(int _result) override;

    /**
     * Amount of time application was started, updated on every startup.
     */
    int ApplicationRunsCount() override;

    /**
     * Will reset any information about application usage.
     */
    void ResetStatistics() override;
    
    /**
     * Store any updated usage statics in a backend storage.
     */
    void UpdateStatistics() override;

    void EmailFeedback() override;
    void EmailSupport() override;
    void RateOnAppStore() override;

private:
    bool IsEligibleForRatingOverlay() const;

    const int m_ApplicationRunsCount;
    const double m_TotalHoursUsed;
    const time_t m_StartupTime;
    const time_t m_FirstRunTime;
    bool m_ShownRatingOverlay = false;
    nc::bootstrap::ActivationManager &m_ActivationManager;

    std::optional<int> m_LastRating; // 0 - discarded, [1-5] - rating
    std::optional<time_t> m_LastRatingTime;
};

} // namespace nc
