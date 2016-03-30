#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <Habanero/algo.h>
#include "GoogleAnalytics.h"

static const auto g_TrackingID = "UA-47180125-2"s;
static const auto g_DefaultsClientIDKey = CFSTR("GATrackingUUID");

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


//+ (NSCharacterSet *)URLPathAllowedCharacterSet NS_AVAILABLE(10_9, 7_0);
//
//// Returns a character set containing the characters allowed in an URL's query component.
//+ (NSCharacterSet *)URLQueryAllowedCharacterSet NS_AVAILABLE(10_9, 7_0);
//
//// Returns a character set containing the characters allowed in an URL's fragment component.
//+ (NSCharacterSet *)URLFragmentAllowedCharacterSet NS_AVAILABLE(10_9, 7_0);
//
//@end
//
//
//@interface NSString (NSURLUtilities)
//
//// Returns a new string made from the receiver by replacing all characters not in the allowedCharacters set with percent encoded characters. UTF-8 encoding is used to determine the correct percent encoded characters. Entire URL strings cannot be percent-encoded. This method is intended to percent-encode an URL component or subcomponent string, NOT the entire URL string. Any characters in allowedCharacters outside of the 7-bit ASCII range are ignored.
//- (nullable NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)allowedCharacters NS_AVAILABLE(10_9, 7_0);


GoogleAnalytics::GoogleAnalytics():
    m_ClientID( GetStoredOrNewClientID() ),
    m_AppName( GetAppName() ),
    m_AppVersion( GetAppVersion() )
{
    cout << "GA user id: " << m_ClientID << endl;
    
    
//    NSDictionary *defaultParams = @{@"v" : kGAVersion, @"tid" : self.trackingId, @"cid" : self.clientId,
//                                    @"an" : @(self.anonymize),
//                                    @"sr" : [self screenResolution],
//                                    @"sd" : [self screenColors],
//                                    @"ul" : [self userLanguage],
//                                    };
//    NSOrderedSet *copyHits = [self.hits copy];
//postdata="v=1&tid=UA-123456-1&cid=UUID&t=pageview&dp=%2FStart%20screen";
//            [params addEntriesFromDictionary:@{ @"sc" : @"start" }];
//        [self.httpClient postPath:@"/collect" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
    
//    NSDictionary *osInfo = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
//    NSLocale *currentLocale = [NSLocale autoupdatingCurrentLocale];
//    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/2.0 (Macintosh; Intel %@ %@; %@-%@)",
//                    osInfo[@"ProductName"], [osInfo[@"ProductVersion"] stringByReplacingOccurrencesOfString:@"." withString:@"_"],
//                    [currentLocale objectForKey:NSLocaleLanguageCode], [currentLocale objectForKey:NSLocaleCountryCode]];
//    [_httpClient setDefaultHeader:@"User-Agent" value:UA];
    
//                                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"],
    
//    - (NSString *)appName { return [[[NSBundle mainBundle] infoDictionary] valueForKey:(id)kCFBundleNameKey]; }
//    - (NSString *)appVersion { return [[[NSBundle mainBundle] infoDictionary] valueForKey:(id)kCFBundleVersionKey]; }
//    - (NSString *)appId { return [[NSBundle mainBundle] bundleIdentifier]; }
    
    
    
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://www.google-analytics.com/collect"]];
    [req setHTTPMethod:@"POST"];
    NSString *post_string = [NSString stringWithFormat:@"v=1&tid=%s&cid=%s&an=%s&av=%s&t=pageview&dp=home",
                             g_TrackingID.c_str(),
                             m_ClientID.c_str(),
                             EscapeString(m_AppName).c_str(),
                             m_AppVersion.c_str()
                             ];
    
    NSData *post_data = [post_string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *post_length = [NSString stringWithFormat:@"%lu",(unsigned long)[post_data length]];
    [req addValue:post_length forHTTPHeaderField:@"Content-Length"];
    [req setHTTPBody:post_data];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                int a = 10;
                                                // Do something with response data here - convert to JSON, check if error exists, etc....
                                            }];
    
    [task resume];
    
//    v=1              // Version.
//    &tid=UA-XXXXX-Y  // Tracking ID / Property ID.
//    &cid=555         // Anonymous Client ID.
//    &t=              // Hit Type.
    
    
}

void GoogleAnalytics::PostPageview(const char *_page)
{
    
    
}

int a = []{
    GoogleAnalytics::Instance();
    return 0;
}();

