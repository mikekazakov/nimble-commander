#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <Habanero/algo.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Utility/SystemInformation.h>
#include "GoogleAnalytics.h"

// TODO: difference IDs for versions
static const auto g_TrackingID = "UA-47180125-2"s;

CFStringRef const GoogleAnalytics::g_DefaultsClientIDKey = CFSTR("GATrackingUUID");
CFStringRef const GoogleAnalytics::g_DefaultsTrackingEnabledKey = CFSTR("GATrackingEnabled");
static const auto g_SendingDelay = 10min;
static const auto g_URLSingle = @"http://www.google-analytics.com/collect";
static const auto g_URLBatch  = @"http://www.google-analytics.com/batch";
static const auto g_MessagesOverflowLimit = 100;

template <typename C, typename T>
static bool has( const C &_c, const T &_v )
{
    auto b = std::begin(_c), e = std::end(_c);
    auto it = std::find( b,  e, _v );
    return it != e;
}

static string GetStoredOrNewClientID()
{
    if( auto stored_id = CFDefaultsGetOptionalString(GoogleAnalytics::g_DefaultsClientIDKey) )
        return *stored_id;

    auto client_id = to_string( boost::uuids::basic_random_generator<boost::mt19937>()() );
    CFDefaultsSetString(GoogleAnalytics::g_DefaultsClientIDKey, client_id);
    return client_id;
}

static string GetAppName()
{
    if( auto s = objc_cast<NSString>([NSBundle.mainBundle.infoDictionary valueForKey:(id)kCFBundleNameKey]) )
        return s.UTF8String;
    return "Unknown";
}

static string GetAppVersion()
{
    if( auto s = objc_cast<NSString>([NSBundle.mainBundle.infoDictionary valueForKey:@"CFBundleShortVersionString"]) )
        return s.UTF8String;
    return "0.0.0";
}

static string EscapeString(const string &_original) // very inefficient
{
    return [[NSString stringWithUTF8StdString:_original] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet].UTF8String;
}

static string EscapeString(const char *_original) // very inefficient
{
    return [[NSString stringWithUTF8String:_original] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet].UTF8String;
}

GoogleAnalytics& GoogleAnalytics::Instance()
{
    static auto inst = new GoogleAnalytics;
    return *inst;
}

//App / Screen Tracking
//v=1                         // Version.
//&tid=UA-XXXXX-Y             // Tracking ID / Property ID.
//&cid=555                    // Anonymous Client ID.
//&t=screenview               // Screenview hit type.
//&an=funTimes                // App name.
//&av=4.2.0                   // App version.
//&aid=com.foo.App            // App Id.
//&aiid=com.android.vending   // App Installer Id.
//&cd=Home                    // Screen name / content description.

//Mozilla/5.0 (Linux; Android 4.4.2; Nexus 5 Build/KOT49H)

//"Files/543 CFNetwork/673.6 Darwin/13.4.0 (x86_64) (MacBookPro5%2C3)"
//"Files/543 CFNetwork/673.6 Darwin/13.4.0 (x86_64) (MacBookPro5%2C3)"
//Mozilla/[version] ([system and browser information]) [platform] ([platform details]) [extensions].

static string UserLanguage()
{
    NSString *lang = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier: [lang isEqualToString:@"en"] ? @"en_US" : lang];
    return [NSString stringWithFormat:@"%@-%@", [locale objectForKey:NSLocaleLanguageCode], [locale objectForKey:NSLocaleCountryCode]].UTF8String;
}

static NSString *GetUserAgent()
{
    sysinfo::SystemOverview sysoverview;
    sysinfo::GetSystemOverview(sysoverview);
    
    NSDictionary *osInfo = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    
    NSLocale *currentLocale = [NSLocale autoupdatingCurrentLocale];
//    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/3.0 (Macintosh; Intel %@ %@; %@-%@; %@)",
/*    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/3.0 (Macintosh; Intel %@ %@; %@)",
                    osInfo[@"ProductName"],
                    [osInfo[@"ProductVersion"] stringByReplacingOccurrencesOfString:@"." withString:@"_"],
//                    [currentLocale objectForKey:NSLocaleLanguageCode],
//                    [currentLocale objectForKey:NSLocaleCountryCode],
                    [NSString stringWithUTF8StdString:sysoverview.coded_model]
                    ];*/
    
    // escaping codel_model?
    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/3.0 (Macintosh; Intel %@ %@; %@-%@) (%@)",
                    osInfo[@"ProductName"],
                    [osInfo[@"ProductVersion"] stringByReplacingOccurrencesOfString:@"." withString:@"_"],
                    [currentLocale objectForKey:NSLocaleLanguageCode],
                    [currentLocale objectForKey:NSLocaleCountryCode],
                    [NSString stringWithUTF8StdString:sysoverview.coded_model]
//                    [[NSString stringWithUTF8StdString:sysoverview.coded_model] stringByReplacingOccurrencesOfString:@"," withString:@"%2C"]
                    ];
    
    return UA;
}

static NSURLSession *GetPostingSession()
{
    static NSURLSession *session = []{
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.discretionary = true;
        config.networkServiceType = NSURLNetworkServiceTypeBackground;
        config.HTTPShouldSetCookies = false;
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        config.HTTPAdditionalHeaders = @{ @"User-Agent": GetUserAgent() };
        
        return [NSURLSession sessionWithConfiguration:config];
    }();
    
    return session;
}

GoogleAnalytics::GoogleAnalytics():
    m_ClientID( GetStoredOrNewClientID() ),
    m_AppName( GetAppName() ),
    m_AppVersion( GetAppVersion() ),
    m_UserLanguage( UserLanguage() ),
    m_Enabled( CFDefaultsGetBool(g_DefaultsTrackingEnabledKey) )
{
    m_PayloadPrefix =   "v=1"s + "&"
                        "tid=" + g_TrackingID + "&" +
                        "cid=" + m_ClientID + "&" +
                        "an="  + EscapeString(m_AppName) + "&" +
                        "av="  + m_AppVersion + "&" +
                        "ul="  + m_UserLanguage + "&";
}

void GoogleAnalytics::UpdateEnabledStatus()
{
    m_Enabled = CFDefaultsGetBool(g_DefaultsTrackingEnabledKey);
}

void GoogleAnalytics::PostScreenView(const char *_screen)
{
    if( !m_Enabled )
        return;
    
    string message = "t=screenview&cd="s + _screen;
    
    AcceptMessage( EscapeString(message) );
}

void GoogleAnalytics::PostEvent(const char *_category, const char *_action, const char *_label, unsigned _value)
{
    if( !m_Enabled )
        return;

    string message = "t=event&ec="s + _category + "&ea=" + _action + "&el=" + _label + "&ev=" + to_string(_value);

    AcceptMessage( EscapeString(message) );
}

void GoogleAnalytics::AcceptMessage(string _message)
{
    if( !m_Enabled )
        return;
    
    LOCK_GUARD(m_MessagesLock) {
        if( m_FilterRedundantMessages && has(m_Messages, _message) )
            return;
        if( m_Messages.size() >= g_MessagesOverflowLimit )
            return;
        
        m_Messages.emplace_back( move(_message) );
    }
    
    MarkDirty();
}

void GoogleAnalytics::MarkDirty()
{
    if( !m_SendingScheduled.test_and_set() )
        dispatch_to_background_after(g_SendingDelay, [=]{
            PostMessages();
            m_SendingScheduled.clear();
        });
}

void GoogleAnalytics::PostMessages()
{
    dispatch_assert_background_queue();
    static auto batch_url = [NSURL URLWithString:g_URLBatch];
    
    vector<string> messages;
    LOCK_GUARD(m_MessagesLock)
        messages = move(m_Messages);
    
    string payload;
    for( size_t ind = 0, ind_max = messages.size(); ind < ind_max; ) {
        
        payload.clear();
        for(int i = 0; i < 20 && ind < ind_max; ++i, ++ind) {
            payload += m_PayloadPrefix;
            payload += messages[ind];
            payload += "\n";
        }
        
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:batch_url];
        req.HTTPMethod = @"POST";
        req.HTTPBody = [NSData dataWithBytes:payload.data() length:payload.length()];
        
        NSURLSessionDataTask *task = [GetPostingSession() dataTaskWithRequest:req completionHandler:^(NSData* d, NSURLResponse* r, NSError* e){}];
        [task resume];
    }
}
