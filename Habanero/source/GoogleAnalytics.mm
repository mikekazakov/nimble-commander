/* Copyright (c) 2016-2017 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#include <chrono>
#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <Cocoa/Cocoa.h>
#include <Habanero/algo.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/GoogleAnalytics.h>

using namespace std;
using namespace std::chrono;

CFStringRef const GoogleAnalytics::g_DefaultsClientIDKey = CFSTR("GATrackingUUID");
CFStringRef const GoogleAnalytics::g_DefaultsTrackingEnabledKey = CFSTR("GATrackingEnabled");

static const auto g_SendingDelay = 10min;
static const auto g_HttpBatch  = @"http://www.google-analytics.com/batch";
static const auto g_HttpsBatch  = @"https://ssl.google-analytics.com/batch";
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
    id v = [NSBundle.mainBundle.infoDictionary valueForKey:(id)kCFBundleNameKey];
    if( [v isKindOfClass:NSString.class] )
        return [v UTF8String];
    return "Unknown";
}

static string GetAppVersion()
{
    id v = [NSBundle.mainBundle.infoDictionary valueForKey:@"CFBundleShortVersionString"];
    if( [v isKindOfClass:NSString.class] )
        return [v UTF8String];
    return "0.0.0";
}

// quite inefficient
static string EscapeString(const char *_original)
{
    static const auto acs = NSCharacterSet.URLQueryAllowedCharacterSet;
    return [[NSString stringWithUTF8String:_original]
        stringByAddingPercentEncodingWithAllowedCharacters:acs].UTF8String;
}

static string EscapeString(const string &_original)
{
    return EscapeString( _original.c_str() );
}

static string UserLanguage()
{
    NSString *lang = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:
        [lang isEqualToString:@"en"] ? @"en_US" : lang];
    return [NSString stringWithFormat:@"%@-%@",
        [locale objectForKey:NSLocaleLanguageCode],
        [locale objectForKey:NSLocaleCountryCode]].UTF8String;
}

static NSString *GetUserAgent()
{
    auto osInfo = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    
    auto currentLocale = NSLocale.autoupdatingCurrentLocale;
    
    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/3.0 (Macintosh; Intel %@ %@; %@-%@)",
                    osInfo[@"ProductName"],
                    [osInfo[@"ProductVersion"] stringByReplacingOccurrencesOfString:@"." withString:@"_"],
                    [currentLocale objectForKey:NSLocaleLanguageCode],
                    [currentLocale objectForKey:NSLocaleCountryCode]
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

GoogleAnalytics::GoogleAnalytics( /* disabled */ )
{
}

GoogleAnalytics::GoogleAnalytics(const char *_tracking_id,
                                 bool _use_https,
                                 bool _filter_redundant_messages):
    m_TrackingID( _tracking_id ),
    m_ClientID( GetStoredOrNewClientID() ),
    m_AppName( GetAppName() ),
    m_AppVersion( GetAppVersion() ),
    m_UserLanguage( UserLanguage() ),
    m_Enabled( CFDefaultsGetBool(g_DefaultsTrackingEnabledKey) ),
    m_UseHTTPS( _use_https ),
    m_FilterRedundantMessages( _filter_redundant_messages )
{
    m_PayloadPrefix =   "v=1"s + "&"
                        "tid=" + m_TrackingID + "&" +
                        "cid=" + m_ClientID + "&" +
                        "an="  + EscapeString(m_AppName) + "&" +
                        "av="  + m_AppVersion + "&" +
                        "ul="  + m_UserLanguage + "&";
}

bool GoogleAnalytics::IsEnabled() const noexcept
{
    return m_Enabled;
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

void GoogleAnalytics::PostEvent(const char *_category,
                                const char *_action,
                                const char *_label,
                                unsigned _value)
{
    if( !m_Enabled )
        return;

    const auto message = "t=event&ec="s + _category +
                         "&ea=" + _action +
                         "&el=" + _label +
                         "&ev=" + to_string(_value);
                         
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
    const auto batch_url = [NSURL URLWithString:m_UseHTTPS ? g_HttpsBatch : g_HttpBatch];
    
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
        
        NSURLSessionDataTask *task = [GetPostingSession() dataTaskWithRequest:req
            completionHandler:^(NSData* d, NSURLResponse* r, NSError* e){}];
        [task resume];
    }
}
