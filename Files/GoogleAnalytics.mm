#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <Habanero/algo.h>
#include <Utility/SystemInformation.h>
#include "GoogleAnalytics.h"

static const auto g_TrackingID = "UA-47180125-2"s;
static const auto g_DefaultsClientIDKey = CFSTR("GATrackingUUID");
static const auto g_SendingDelay = /*2min*/10s;
static const auto g_URLSingle = @"http://www.google-analytics.com/collect";

//
//NSString *const kGAVersion = @"1";
//NSString *const kGAErrorDomain = @"com.google-analytics.errorDomain";
//NSString *const kGAReceiverURLString = @"http://www.google-analytics.com/collect";


static optional<string> GetDefaultsString(CFStringRef _key)
{
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return nullopt;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) ==  CFStringGetTypeID() )
        return CFStringGetUTF8StdString( (CFStringRef)val );
    
    return nullopt;
}

static void SetDefaultsString(CFStringRef _key, const string &_value)
{
    CFStringRef str = CFStringCreateWithUTF8StdString(_value);
    CFPreferencesSetAppValue(_key, str, kCFPreferencesCurrentApplication);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
    CFRelease(str);
}

static string GetStoredOrNewClientID()
{
    if( auto stored_id = GetDefaultsString(g_DefaultsClientIDKey) )
        return *stored_id;
    
    auto client_id = to_string( boost::uuids::basic_random_generator<boost::mt19937>()() );
    SetDefaultsString(g_DefaultsClientIDKey, client_id);
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

static NSString *GetUserAgent()
{
    sysinfo::SystemOverview sysoverview;
    sysinfo::GetSystemOverview(sysoverview);
    
    NSDictionary *osInfo = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    
    NSLocale *currentLocale = [NSLocale autoupdatingCurrentLocale];
    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/2.0 (Macintosh; Intel %@ %@; %@-%@; %@)",
                    osInfo[@"ProductName"],
                    [osInfo[@"ProductVersion"] stringByReplacingOccurrencesOfString:@"." withString:@"_"],
                    [currentLocale objectForKey:NSLocaleLanguageCode],
                    [currentLocale objectForKey:NSLocaleCountryCode],
                    [NSString stringWithUTF8StdString:sysoverview.coded_model]
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
    m_AppVersion( GetAppVersion() )
{
    m_PayloadPrefix =   "v=1"s + "&"
                        "tid=" + g_TrackingID + "&" +
                        "cid=" + m_ClientID + "&" +
                        "an="  + EscapeString(m_AppName) + "&" +
                        "av="  + m_AppVersion + "&";
}

void GoogleAnalytics::PostScreenView(const char *_screen)
{
    // TODO: check if analytics is off
    
    string message = "t=screenview&cd=";
    message += EscapeString(_screen);
    
    LOCK_GUARD(m_MessagesLock)
        m_Messages.emplace_back( move(message) );
    
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
    static auto single_url = [NSURL URLWithString:g_URLSingle];
    
    vector<string> messages;
    LOCK_GUARD(m_MessagesLock)
        messages = move(m_Messages);
    
    
    for(auto &message: messages) {
        string payload = m_PayloadPrefix + message;
        
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:single_url];
        [req setHTTPMethod:@"POST"];
        
        // use setValue
        NSData *post_data = [NSData dataWithBytes:payload.data() length:payload.length()];
//        [req addValue:[NSString stringWithFormat:@"%lu", post_data.length] forHTTPHeaderField:@"Content-Length"];
//        [req addValue:UA forHTTPHeaderField:@"User-Agent"];
        [req setHTTPBody:post_data];
        
        NSURLSessionDataTask *task = [GetPostingSession() dataTaskWithRequest:req completionHandler:^(NSData*, NSURLResponse*, NSError*){}];
        [task resume];
    }
}
