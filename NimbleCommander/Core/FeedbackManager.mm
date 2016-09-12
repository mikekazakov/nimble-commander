#include <Habanero/CFDefaultsCPP.h>
#include "../../Files/ActivationManager.h"
#include "../GeneralUI/FeedbackWindow.h"
#include "FeedbackManager.h"

static const auto g_RunsKey = CFSTR("feedbackApplicationRunsCount");
static const auto g_HoursKey = CFSTR("feedbackHoursUsedCount");
static const auto g_FirstRunKey = CFSTR("feedbackFirstRun");
static const auto g_LastRatingKey = CFSTR("feedbackLastRating");
static const auto g_LastRatingTimeKey = CFSTR("feedbackLastRating");


static int GetAndUpdateRunsCount()
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

static double GetTotalHoursUsed()
{
    double v = CFDefaultsGetDouble(g_HoursKey);
    if( v < 0 )
        v = 0;
    return v;
}

static time_t GetOrSetFirstRunTime()
{
    const auto now = time(nullptr);
    if( auto t = CFDefaultsGetOptionalLong(g_FirstRunKey) ) {
        if( *t < now )
            return *t;
    }
    CFDefaultsSetLong(g_FirstRunKey, now);
    return now;
}

FeedbackManager::FeedbackManager():
    m_ApplicationRunsCount( GetAndUpdateRunsCount() ),
    m_StartupTime( time(nullptr) ),
    m_TotalHoursUsed( GetTotalHoursUsed() ),
    m_FirstRunTime( GetOrSetFirstRunTime() ),
    m_LastRating( CFDefaultsGetOptionalInt(g_LastRatingKey) ),
    m_LastRatingTime( CFDefaultsGetOptionalLong(g_LastRatingKey) )
{
    atexit([]{
        auto &i = FeedbackManager::Instance();
        auto d = time(nullptr) - i.m_StartupTime;
        if( d < 0 )
            d = 0;
        CFDefaultsSetDouble(g_HoursKey, i.m_TotalHoursUsed + (double)d / 3600.);
    });
}

FeedbackManager& FeedbackManager::Instance()
{
    static auto i = new FeedbackManager;
    return *i;
}

void FeedbackManager::CommitRatingOverlayResult(int _result)
{
    if( _result < 0 || _result > 5 )
        return;
    
    m_LastRating = _result;
    m_LastRatingTime = time(nullptr);
    
    CFDefaultsSetInt(g_LastRatingKey, *m_LastRating);
    CFDefaultsSetLong(g_LastRatingTimeKey, *m_LastRatingTime);
    
    if( _result > 0 ) {
        // used clicked at some star - lets show a window then
        FeedbackWindow *w = [[FeedbackWindow alloc] init];
        w.rating = _result;
        [w showWindow:nil];
    }
}

bool FeedbackManager::ShouldShowRatingOverlayView()
{
    if( m_ShownRatingOverlay )
        return false; // show only once per run anyway
    
    return m_ShownRatingOverlay = true;    
    
    const auto now = time(nullptr);
    const auto repeated_show_delay_on_result = 180l * 24l * 3600l; // 180 days
    const auto repeated_show_delay_on_discard = 7l * 24l * 3600l; // 7 days
    const auto min_runs = 20;
    const auto min_hours = 10;
    const auto min_days = 14;
    
    if( m_LastRating  ) {
        // user had reacted to rating overlay at least once
        const auto when = m_LastRatingTime.value_or(0);
        if( *m_LastRating == 0  ) {
            // user has discarded question
            if( now - when > repeated_show_delay_on_discard  ) {
                // we can let ourselves to try to bother user again
                return m_ShownRatingOverlay = true;
            }
        }
        else {
            // used has clicked to some star
            if( now - when > repeated_show_delay_on_result  ) {
                // it was a long time ago, we can ask for rating again
                return m_ShownRatingOverlay = true;
            }
        }
    }
    else {
        // nope, user did never reacted to rating overlay - just check input params to find if it's time to show
        const auto runs = m_ApplicationRunsCount;
        const auto hours_used = m_TotalHoursUsed;
        const auto days_since_first_run =  (time(nullptr) - m_FirstRunTime) / ( 24l * 3600l );
        
        if( runs >= min_runs &&
            hours_used >= min_hours &&
            days_since_first_run >= min_days )
            return m_ShownRatingOverlay = true;
    }
    
    return false;
}

void FeedbackManager::ResetStatistics()
{
    CFDefaultsRemoveValue(g_RunsKey);
    CFDefaultsRemoveValue(g_HoursKey);
    CFDefaultsRemoveValue(g_FirstRunKey);
    CFDefaultsRemoveValue(g_LastRatingKey);
    CFDefaultsRemoveValue(g_LastRatingTimeKey);
}

void FeedbackManager::EmailFeedback()
{
    NSString *toAddress = @"feedback@magnumbytes.com";
    NSString *subject = [NSString stringWithFormat: @"Feedback on %@ version %@ (%@)",
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleName"],
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"],
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"]];
    NSString *bodyText = @"Write your message here.";
    NSString *mailtoAddress = [NSString stringWithFormat:@"mailto:%@?Subject=%@&body=%@", toAddress, subject, bodyText];
    NSString *urlstring = [mailtoAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlstring]];
}

void FeedbackManager::RateOnAppStore()
{
    NSString *mas_url = [NSString stringWithFormat:@"macappstore://itunes.apple.com/app/id%s",
                                 ActivationManager::Instance().AppStoreID().c_str()];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:mas_url]];
}

static const auto g_SocialMessage = @"I use Nimble Commander - a dual-pane file manager for macOS, and it's great! http://magnumbytes.com/";

void FeedbackManager::ShareOnFacebook()
{
    if( auto fb = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnFacebook] )
        [fb performWithItems:@[g_SocialMessage]];
}

void FeedbackManager::ShareOnTwitter()
{
    if( auto tw = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter] )
        [tw performWithItems:@[g_SocialMessage]];
}

void FeedbackManager::ShareOnLinkedIn()
{
    if( auto li = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnLinkedIn] )
        [li performWithItems:@[g_SocialMessage]];
}
