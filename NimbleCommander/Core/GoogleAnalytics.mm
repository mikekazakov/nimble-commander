// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SystemInformation.h>
#include <NimbleCommander/Bootstrap/NCE.h>
#include "GoogleAnalytics.h"
#include <Habanero/dispatch_cpp.h>
#include <Cocoa/Cocoa.h>

static void PostStartupInfo()
{
    nc::utility::SystemOverview so;
    if( nc::utility::GetSystemOverview(so) )
        GA().PostEvent("Init info", "Hardware", so.coded_model.c_str());

    NSString *lang = [NSLocale.autoupdatingCurrentLocale objectForKey:NSLocaleLanguageCode];
    GA().PostEvent("Init info", "UI Language", lang.UTF8String);
}

static const char *TrackingID()
{
#if defined(__NC_VERSION_FREE__)
    return NCE(nc::env::ga_mas_free);
#elif defined(__NC_VERSION_PAID__)
    return NCE(nc::env::ga_mas_paid);
#elif defined(__NC_VERSION_TRIAL__)
    return NCE(nc::env::ga_nonmas_trial);
#else
#error Invalid build configuration - no version type specified
#endif
}

GoogleAnalytics &GA() noexcept
{
    static GoogleAnalytics *inst = [] {
        const auto ga = new GoogleAnalytics(TrackingID());
        if( ga->IsEnabled() )
            dispatch_to_background(PostStartupInfo);
        return ga;
    }();

    return *inst;
}
