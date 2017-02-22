#include <Utility/SystemInformation.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "GoogleAnalytics.h"

static void PostStartupInfo()
{
    sysinfo::SystemOverview so;
    if( sysinfo::GetSystemOverview(so) )
        GA().PostEvent("Init info", "Hardware", so.coded_model.c_str());
    
    NSString* lang = [NSLocale.autoupdatingCurrentLocale objectForKey:NSLocaleLanguageCode];
    GA().PostEvent( "Init info", "UI Language", [lang UTF8String] );
}

GoogleAnalytics& GA() noexcept
{
    static GoogleAnalytics *inst = []{
        const auto tracking_id =
             ActivationManager::Type() == ActivationManager::Distribution::Trial ? "UA-47180125-2" :
            (ActivationManager::Type() == ActivationManager::Distribution::Free  ? "UA-47180125-3" :
                                                                                   "UA-47180125-4");
    
        const auto ga = new GoogleAnalytics(tracking_id);
        if( ga->IsEnabled() )
            dispatch_to_background( PostStartupInfo );
        return ga;
    }();
    
    return *inst;
}
