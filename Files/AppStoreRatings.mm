//
//  AppStoreRatings.cpp
//  Files
//
//  Created by Michael G. Kazakov on 15/02/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <SystemConfiguration/SystemConfiguration.h>
#include "AppStoreRatings.h"
#include "AppStoreRatingsSheetController.h"

static NSString *g_StateKey = @"CommonRatingsState";
static NSString *g_RunsKey = @"CommonRatingsRuns";
static NSString *g_FirstKey = @"CommonRatingsFirst";
static NSString *g_LaterKey = @"CommonRatingsLater";

// http://stackoverflow.com/questions/7627058/how-to-determine-internet-connection-in-cocoa
static bool isInternetConnection()
{
    bool returnValue = false;
    
    struct sockaddr zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sa_len = sizeof(zeroAddress);
    zeroAddress.sa_family = AF_INET;
    
    if (auto reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr*)&zeroAddress)) {
        SCNetworkReachabilityFlags flags = 0;
        if(SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) {
            BOOL isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
            BOOL connectionRequired = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
            returnValue = (isReachable && !connectionRequired) ? true : false;
        }
        CFRelease(reachabilityRef);
    }
    return returnValue;
}

AppStoreRatings::AppStoreRatings()
{
}

AppStoreRatings& AppStoreRatings::Instance()
{
    static auto me = new AppStoreRatings;
    return *me;
}

void AppStoreRatings::Go()
{
    dispatch_to_background([=]{
        GoBackground();
    });    
}

void AppStoreRatings::GoBackground()
{
    switch (State()) {
        case RatingState::Rated:
        case RatingState::Denied:
            return; // nothing to do
            
        case RatingState::Later:
            if( IsLaterDue() )
                RunDialog();
            return;
            
        default:
            auto num_runs = Runs();
            auto num_days = DaysUsed();
            if( num_runs >= MinRuns && num_days >= MinDays) {
                RunDialog();
                return;
            }
            
            SetRuns(++num_runs);
            return;
    }
}

void AppStoreRatings::RunDialog()
{
    if(!isInternetConnection())
        return;
    
    dispatch_to_main_queue([=]{
        AppStoreRatingsSheetController *sheet = [AppStoreRatingsSheetController new];
        NSModalResponse ret = sheet.runModal;
        
        if( ret == NSAlertFirstButtonReturn ) { // review
            [NSWorkspace.sharedWorkspace openURL:MasURL()];
            SetState(RatingState::Rated);
        }
        else if( ret == NSAlertSecondButtonReturn ) { // later
            SetLaterDate();
            SetState(RatingState::Later);
        }
        else if( ret == NSAlertThirdButtonReturn ) { // no, thanks
            SetState(RatingState::Denied);
        }
    });
}


NSURL *AppStoreRatings::MasURL()
{
    NSString *mas_url = [NSString stringWithFormat:@"macappstore://itunes.apple.com/app/id%s",
                                     configuration::appstore_id];
    return [NSURL URLWithString:mas_url];
}

AppStoreRatings::RatingState AppStoreRatings::State()
{
    auto st = (RatingState)[NSUserDefaults.standardUserDefaults integerForKey:g_StateKey];
    if(st < RatingState::Default || st > RatingState::Later)
        st = RatingState::Default;
    return st;
}

void AppStoreRatings::SetState(RatingState _state)
{
    [NSUserDefaults.standardUserDefaults setInteger:(int)_state forKey:g_StateKey];
}

int AppStoreRatings::Runs()
{
    return (int)[NSUserDefaults.standardUserDefaults integerForKey:g_RunsKey];
}

void AppStoreRatings::SetRuns(int _runs)
{
    [NSUserDefaults.standardUserDefaults setInteger:_runs forKey:g_RunsKey];
}

int AppStoreRatings::DaysUsed()
{
    if(NSData *d = [NSUserDefaults.standardUserDefaults dataForKey:g_FirstKey])
        if(auto first_run = objc_cast<NSDate>([NSUnarchiver unarchiveObjectWithData:d])) {
            NSTimeInterval diff = first_run.timeIntervalSinceNow;
            return int(duration_cast<hours>(seconds(long(-diff))).count() / 24);
        }
    
    [NSUserDefaults.standardUserDefaults setObject:[NSArchiver archivedDataWithRootObject:NSDate.date] forKey:g_FirstKey];
    return 0;
}

void AppStoreRatings::SetLaterDate()
{
    NSDate *later = [NSDate dateWithTimeInterval:LaterDays*24*60*60 sinceDate:NSDate.date];
    [NSUserDefaults.standardUserDefaults setObject:[NSArchiver archivedDataWithRootObject:later] forKey:g_LaterKey];
}

bool AppStoreRatings::IsLaterDue()
{
    if(NSData *d = [NSUserDefaults.standardUserDefaults dataForKey:g_LaterKey])
        if(auto due = objc_cast<NSDate>([NSUnarchiver unarchiveObjectWithData:d]))
            return due.timeIntervalSinceNow < 0;
    
    SetLaterDate();
    return false;
}
