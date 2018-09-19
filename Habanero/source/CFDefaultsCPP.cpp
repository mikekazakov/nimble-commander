/* Copyright (c) 2016 Michael G. Kazakov
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
#include <Habanero/CFStackAllocator.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/algo.h>
#include <Habanero/CFString.h>

using namespace std;

optional<int> CFDefaultsGetOptionalInt(CFStringRef _key)
{
    int result = 0;
    
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return nullopt;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = (CFNumberRef)val;
        CFNumberGetValue(num, kCFNumberIntType, &result);
    }
    
    return result;
}

optional<long> CFDefaultsGetOptionalLong(CFStringRef _key)
{
    long result = 0;
    
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return nullopt;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = (CFNumberRef)val;
        CFNumberGetValue(num, kCFNumberLongType, &result);
    }
    
    return result;
}

optional<double> CFDefaultsGetOptionalDouble(CFStringRef _key)
{
    double result = 0;
    
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return nullopt;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = (CFNumberRef)val;
        CFNumberGetValue(num, kCFNumberDoubleType, &result);
    }
    
    return result;
}

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

int CFDefaultsGetInt(CFStringRef _key)
{
    int result = 0.;
    
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return result;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = (CFNumberRef)val;
        CFNumberGetValue(num, kCFNumberIntType, &result);
    }
    
    return result;
}

long CFDefaultsGetLong(CFStringRef _key)
{
    long result = 0.;
    
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return result;
    auto release_val = at_scope_end([=]{ CFRelease(val); });
    
    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = (CFNumberRef)val;
        CFNumberGetValue(num, kCFNumberLongType, &result);
    }
    
    return result;
}

void CFDefaultsSetDouble(CFStringRef _key, double _value)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberDoubleType, &_value);
    if( num == nullptr )
        return;
    auto release_val = at_scope_end([=]{ CFRelease(num); });
    CFPreferencesSetAppValue(_key, num, kCFPreferencesCurrentApplication);
}

void CFDefaultsSetInt(CFStringRef _key, int _value)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberIntType, &_value);
    if( num == nullptr )
        return;
    auto release_val = at_scope_end([=]{ CFRelease(num); });
    CFPreferencesSetAppValue(_key, num, kCFPreferencesCurrentApplication);
}

void CFDefaultsSetLong(CFStringRef _key, long _value)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberLongType, &_value);
    if( num == nullptr )
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

void CFDefaultsRemoveValue(CFStringRef _key)
{
    CFPreferencesSetAppValue(_key, nullptr, kCFPreferencesCurrentApplication);
}
