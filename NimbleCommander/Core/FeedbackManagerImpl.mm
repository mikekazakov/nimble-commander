// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FeedbackManagerImpl.h"
#include <SystemConfiguration/SystemConfiguration.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/GoogleAnalytics.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "../GeneralUI/FeedbackWindow.h"
#include <Habanero/dispatch_cpp.h>

namespace nc {

const CFStringRef FeedbackManagerImpl::g_RunsKey = CFSTR("feedbackApplicationRunsCount");
const CFStringRef FeedbackManagerImpl::g_HoursKey = CFSTR("feedbackHoursUsedCount");
const CFStringRef FeedbackManagerImpl::g_FirstRunKey = CFSTR("feedbackFirstRun");
const CFStringRef FeedbackManagerImpl::g_LastRatingKey = CFSTR("feedbackLastRating");
const CFStringRef FeedbackManagerImpl::g_LastRatingTimeKey = CFSTR("feedbackLastRatingTime");
[[clang::no_destroy]] const std::function<time_t()> FeedbackManagerImpl::g_DefaultTimeSource = [] {
    return std::time(nullptr);
};

// http://stackoverflow.com/questions/7627058/how-to-determine-internet-connection-in-cocoa
static bool HasInternetConnection()
{
    bool returnValue = false;

    struct sockaddr zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sa_len = sizeof(zeroAddress);
    zeroAddress.sa_family = AF_INET;

    if( auto reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, &zeroAddress) ) {
        SCNetworkReachabilityFlags flags = 0;
        if( SCNetworkReachabilityGetFlags(reachabilityRef, &flags) ) {
            bool isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
            bool connectionRequired = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
            returnValue = (isReachable && !connectionRequired) ? true : false;
        }
        CFRelease(reachabilityRef);
    }
    return returnValue;
}

FeedbackManagerImpl::FeedbackManagerImpl(nc::bootstrap::ActivationManager &_am,
                                         base::GoogleAnalytics &_ga,
                                         std::function<time_t()> _time_source)
    : m_ApplicationRunsCount(GetAndUpdateRunsCount()), m_TotalHoursUsed(GetTotalHoursUsed()),
      m_StartupTime(_time_source()), m_ActivationManager(_am), m_GA(_ga),
      m_TimeSource(_time_source), m_LastRating(CFDefaultsGetOptionalInt(g_LastRatingKey)),
      m_LastRatingTime(CFDefaultsGetOptionalLong(g_LastRatingTimeKey))
{
    m_FirstRunTime = GetOrSetFirstRunTime();
}

void FeedbackManagerImpl::CommitRatingOverlayResult(int _result)
{
    dispatch_assert_main_queue();

    if( _result < 0 || _result > 5 )
        return;

    const char *labels[] = {"Discard", "1 Star", "2 Stars", "3 Stars", "4 Stars", "5 Stars"};
    m_GA.PostEvent("Feedback", "Rating Overlay Choice", labels[_result]);

    m_LastRating = _result;
    m_LastRatingTime = m_TimeSource();

    CFDefaultsSetInt(g_LastRatingKey, *m_LastRating);
    CFDefaultsSetLong(g_LastRatingTimeKey, *m_LastRatingTime);

    if( m_HasUI && _result > 0 ) {
        // used clicked at some star - lets show a window then
        FeedbackWindow *w = [[FeedbackWindow alloc] initWithActivationManager:m_ActivationManager
                                                              feedbackManager:*this];
        w.rating = _result;
        [w showWindow:nil];
    }
}

bool FeedbackManagerImpl::ShouldShowRatingOverlayView()
{
    if( IsEligibleForRatingOverlay() )
        if( HasInternetConnection() ) {
            m_GA.PostEvent("Feedback", "Rating Overlay Shown", "Shown");
            return m_ShownRatingOverlay = true;
        }

    return false;
}

bool FeedbackManagerImpl::IsEligibleForRatingOverlay() const
{
    if( m_ShownRatingOverlay )
        return false; // show only once per run anyway

    const auto now = m_TimeSource();
    const auto repeated_show_delay_on_result = 365l * 24l * 3600l; // 365 days
    const auto repeated_show_delay_on_discard = 14l * 24l * 3600l; // 14 days
    const auto min_runs = 20;
    const auto min_hours = 10.;
    const auto min_days = 10;

    if( m_LastRating ) {
        // user had reacted to rating overlay at least once
        const auto when = m_LastRatingTime.value_or(0);
        if( *m_LastRating == 0 ) {
            // user has discarded question
            if( now - when >= repeated_show_delay_on_discard ) {
                // we can let ourselves to try to bother user again
                return true;
            }
        }
        else {
            // used has clicked to some star
            if( now - when >= repeated_show_delay_on_result ) {
                // it was a long time ago, we can ask for rating again
                return true;
            }
        }
    }
    else {
        // nope, user did never reacted to rating overlay - just check input params to find if it's
        // time to show
        const auto runs = m_ApplicationRunsCount;
        const auto hours_used = m_TotalHoursUsed;
        const auto days_since_first_run = (m_TimeSource() - m_FirstRunTime) / (24l * 3600l);

        if( runs >= min_runs && hours_used >= min_hours && days_since_first_run >= min_days )
            return true;
    }

    return false;
}

void FeedbackManagerImpl::ResetStatistics()
{
    CFDefaultsRemoveValue(g_RunsKey);
    CFDefaultsRemoveValue(g_HoursKey);
    CFDefaultsRemoveValue(g_FirstRunKey);
    CFDefaultsRemoveValue(g_LastRatingKey);
    CFDefaultsRemoveValue(g_LastRatingTimeKey);
}

void FeedbackManagerImpl::UpdateStatistics()
{
    auto d = m_TimeSource() - m_StartupTime;
    if( d < 0 )
        d = 0;
    CFDefaultsSetDouble(g_HoursKey, m_TotalHoursUsed + static_cast<double>(d) / 3600.);
}

void FeedbackManagerImpl::EmailFeedback()
{
    m_GA.PostEvent("Feedback", "Action", "Email Feedback");
    const auto info = NSBundle.mainBundle.infoDictionary;
    NSString *toAddress = @"feedback@magnumbytes.com";
    NSString *subject =
        [NSString stringWithFormat:@"Feedback on %@ version %@ (%@)",
                                   [info objectForKey:@"CFBundleName"],
                                   [info objectForKey:@"CFBundleShortVersionString"],
                                   [info objectForKey:@"CFBundleVersion"]];
    NSString *bodyText = @"Please write your feedback here.";
    NSString *mailtoAddress =
        [NSString stringWithFormat:@"mailto:%@?Subject=%@&body=%@", toAddress, subject, bodyText];

    NSString *urlstring = [mailtoAddress
        stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet
                                                               .URLQueryAllowedCharacterSet];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlstring]];
}

void FeedbackManagerImpl::EmailSupport()
{
    m_GA.PostEvent("Feedback", "Action", "Email Support");
    const auto info = NSBundle.mainBundle.infoDictionary;
    NSString *toAddress = @"support@magnumbytes.com";
    NSString *subject =
        [NSString stringWithFormat:@"Support for %@ version %@ (%@)",
                                   [info objectForKey:@"CFBundleName"],
                                   [info objectForKey:@"CFBundleShortVersionString"],
                                   [info objectForKey:@"CFBundleVersion"]];
    NSString *bodyText = @"Please describle your issues with Nimble Commander here.";
    NSString *mailtoAddress =
        [NSString stringWithFormat:@"mailto:%@?Subject=%@&body=%@", toAddress, subject, bodyText];
    NSString *urlstring = [mailtoAddress
        stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet
                                                               .URLQueryAllowedCharacterSet];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlstring]];
}

void FeedbackManagerImpl::RateOnAppStore()
{
    // https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requesting_app_store_reviews
    m_GA.PostEvent("Feedback", "Action", "Rate on AppStore");
    const auto fmt = @"https://apps.apple.com/app/id%s?action=write-review";
    const auto review_url =
        [NSString stringWithFormat:fmt, m_ActivationManager.AppStoreID().c_str()];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:review_url]];
}

int FeedbackManagerImpl::ApplicationRunsCount()
{
    return m_ApplicationRunsCount;
}

int FeedbackManagerImpl::GetAndUpdateRunsCount()
{
    if( auto runs = CFDefaultsGetOptionalInt(g_RunsKey) ) {
        int v = *runs;
        if( v < 1 ) {
            v = 1;
            CFDefaultsSetInt(g_RunsKey, v);
        }
        else {
            CFDefaultsSetInt(g_RunsKey, v + 1);
        }
        return v;
    }
    else {
        CFDefaultsSetInt(g_RunsKey, 1);
        return 1;
    }
}

double FeedbackManagerImpl::GetTotalHoursUsed()
{
    double v = CFDefaultsGetDouble(g_HoursKey);
    if( v < 0 )
        v = 0;
    return v;
}

time_t FeedbackManagerImpl::GetOrSetFirstRunTime() const
{
    const auto now = m_TimeSource();
    if( auto t = CFDefaultsGetOptionalLong(g_FirstRunKey) ) {
        if( *t < now )
            return *t;
    }
    CFDefaultsSetLong(g_FirstRunKey, now);
    return now;
}

double FeedbackManagerImpl::TotalHoursUsed() const noexcept
{
    return m_TotalHoursUsed;
}

void FeedbackManagerImpl::SetHasUI(bool _has_ui)
{
    m_HasUI = _has_ui;
}

}
