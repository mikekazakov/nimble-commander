#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/algo.h>
#include <Habanero/CFString.h>

using namespace std;
using namespace std::experimental;

bool CFDefaultsGetBool(CFStringRef _key)
{
    return CFPreferencesGetAppBooleanValue(_key, kCFPreferencesCurrentApplication, nullptr);
}

optional<bool> CFDefaultsGetOptionalBool(CFStringRef _key)
{
    Boolean has = false;
    Boolean v = CFPreferencesGetAppBooleanValue(_key, kCFPreferencesCurrentApplication, &has);
    if( !has )
        return nullopt;
    return v ? true : false;
}

void CFDefaultsSetBool(CFStringRef _key, bool _value)
{
    CFPreferencesSetAppValue(_key, _value ? kCFBooleanTrue : kCFBooleanFalse, kCFPreferencesCurrentApplication);
}

double CFDefaultsGetDouble(CFStringRef _key)
{
    double result = 0.;
    
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return result;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = (CFNumberRef)val;
        CFNumberGetValue(num, kCFNumberDoubleType, &result);
    }
    
    return result;
}

void CFDefaultsSetDouble(CFStringRef _key, double _value)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberDoubleType, &_value);
    if( !num )
        return;
    auto release_val = at_scope_end([=]{ CFRelease(num); });
    CFPreferencesSetAppValue(_key, num, kCFPreferencesCurrentApplication);
}

string CFDefaultsGetString(CFStringRef _key)
{
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return "";
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) ==  CFStringGetTypeID() )
        return CFStringGetUTF8StdString( (CFStringRef)val );
    
    return "";
}

optional<string> CFDefaultsGetOptionalString(CFStringRef _key)
{
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return nullopt;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) ==  CFStringGetTypeID() )
        return CFStringGetUTF8StdString( (CFStringRef)val );
    
    return nullopt;
}

void CFDefaultsSetString(CFStringRef _key, const std::string &_value)
{
    CFStringRef str = CFStringCreateWithUTF8StdString(_value);
    if( !str )
        return;
    auto release_val = at_scope_end([=]{ CFRelease(str); });
    CFPreferencesSetAppValue(_key, str, kCFPreferencesCurrentApplication);
}
