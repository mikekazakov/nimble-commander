// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc {

class FeedbackManager
{
public:
    virtual ~FeedbackManager() = default;
    
    /**
     * Decides if a rating overlay needs to be shown, based on usage statistics.
     * Can return true only once per run - assumes that this function is called only once per
     * window.
     */
    virtual bool ShouldShowRatingOverlayView() = 0;

    /**
     * 0: discard button was clicked (default).
     * [1-5]: amount of stars assigned.
     */
    virtual void CommitRatingOverlayResult(int _result) = 0;

    /**
     * Amount of times application was started, updated on every startup.
     */
    virtual int ApplicationRunsCount() = 0;

    /**
     * Will reset any information about application usage.
     */
    virtual void ResetStatistics() = 0;
    
    /**
     * Store any updated usage statics in a backend storage.
     */
    virtual void UpdateStatistics() = 0;

    virtual void EmailFeedback() = 0;
    virtual void EmailSupport() = 0;
    virtual void RateOnAppStore() = 0;
};

} // namespace nc
