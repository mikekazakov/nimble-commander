#pragma once

class FeedbackManager
{
public:
    static FeedbackManager& Instance();
    
    
    /**
     * Decided if rating overlay need to be shown, based on usage statistics.
     * Can return true only once per run - assumes that this function is called only once per window.
     */
    bool ShouldShowRatingOverlayWindow();
    
    /**
     * 0: discard button was clicked (default)
     * [1-5]: amount of stars assigned
     */
    void CommitRatingOverlayResult(int _result);
    
private:
    
    
};
