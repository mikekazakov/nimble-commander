// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "FeedbackManager.h"
#include <CoreFoundation/CoreFoundation.h>
#include <optional>
#include <functional>
#include <ctime>

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc {

class FeedbackManagerImpl : public FeedbackManager
{
public:
    static const CFStringRef g_RunsKey;
    static const CFStringRef g_HoursKey;
    static const CFStringRef g_FirstRunKey;
    static const CFStringRef g_LastRatingKey;
    static const CFStringRef g_LastRatingTimeKey;
    static const std::function<time_t()> g_DefaultTimeSource;
    
    FeedbackManagerImpl(nc::bootstrap::ActivationManager &_am,
                        std::function<time_t()> _time_source = g_DefaultTimeSource);
    
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
    
    double TotalHoursUsed() const noexcept;
    bool IsEligibleForRatingOverlay() const;
    
    void SetHasUI(bool _has_ui);
private:
    
    time_t GetOrSetFirstRunTime() const;
    static int GetAndUpdateRunsCount();
    static double GetTotalHoursUsed();

    const int m_ApplicationRunsCount;
    const double m_TotalHoursUsed;
    time_t m_StartupTime;
    time_t m_FirstRunTime;
    bool m_ShownRatingOverlay = false;
    bool m_HasUI = true;
    nc::bootstrap::ActivationManager &m_ActivationManager;
    std::function<time_t()> m_TimeSource;

    std::optional<int> m_LastRating; // 0 - discarded, [1-5] - rating
    std::optional<time_t> m_LastRatingTime;
};

} // namespace nc
