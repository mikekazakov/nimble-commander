//
//  AppStoreRatings.h
//  Files
//
//  Created by Michael G. Kazakov on 15/02/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

class AppStoreRatings
{
public:
    static AppStoreRatings& Instance();
    
    void Go();
    
private:
    enum class RatingState { // persistance-bound
        Default = 0,
        Rated   = 1,
        Denied  = 2,
        Later   = 3
    };
    
    enum {
        MinRuns   = 20,
        MinDays   = 14,
        LaterDays =  3
    };

    AppStoreRatings();
    
    RatingState State();
    void SetState(RatingState _state);
    int Runs();
    void SetRuns(int _runs);
    int DaysUsed();
    void SetLaterDate();
    bool IsLaterDue();
    
    void GoBackground();
    void RunDialog();
    NSURL *MasURL();
};
