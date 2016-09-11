#include "FeedbackManager.h"

FeedbackManager& FeedbackManager::Instance()
{
    static auto i = new FeedbackManager;
    return *i;
}

void FeedbackManager::CommitRatingOverlayResult(int _result)
{
//    int a = 10;
    
}

bool FeedbackManager::ShouldShowRatingOverlayWindow()
{
    return false;
}
