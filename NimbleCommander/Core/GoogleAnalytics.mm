#include <Utility/SystemInformation.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "GoogleAnalytics.h"

GoogleAnalytics& GA() noexcept
{
    static GoogleAnalytics *inst;
    static once_flag once;
    call_once(once, []{
        const auto tracking_id =
             ActivationManager::Type() == ActivationManager::Distribution::Trial ? "UA-47180125-2" :
            (ActivationManager::Type() == ActivationManager::Distribution::Free  ? "UA-47180125-3" :
                                                                                   "UA-47180125-4");
    
        inst = new GoogleAnalytics(tracking_id);
        if( inst->IsEnabled() ) {
            sysinfo::SystemOverview so;
            if( sysinfo::GetSystemOverview(so) )
                inst->PostEvent("Init info", "Hardware", so.coded_model.c_str());
    
            inst->PostEvent("Init info", "UI Language",
              [[NSLocale.autoupdatingCurrentLocale objectForKey:NSLocaleLanguageCode] UTF8String] );
        }
    });
    
    return *inst;
}
