// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/CFStackAllocator.h>
#include <Base/CFDefaultsCPP.h>
#include <Base/algo.h>
#include <Base/CFString.h>

namespace nc::base {

bool CFDefaultsHasValue(CFStringRef _key) noexcept
{
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( val == nullptr )
        return false;
    CFRelease(val);
    return true;
}

std::optional<int> CFDefaultsGetOptionalInt(CFStringRef _key) noexcept
{
    int result = 0;

    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return {};
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = static_cast<CFNumberRef>(val);
        CFNumberGetValue(num, kCFNumberIntType, &result);
    }

    return result;
}

std::optional<long> CFDefaultsGetOptionalLong(CFStringRef _key) noexcept
{
    long result = 0;

    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return {};
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = static_cast<CFNumberRef>(val);
        CFNumberGetValue(num, kCFNumberLongType, &result);
    }

    return result;
}

std::optional<double> CFDefaultsGetOptionalDouble(CFStringRef _key) noexcept
{
    double result = 0;

    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return {};
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = static_cast<CFNumberRef>(val);
        CFNumberGetValue(num, kCFNumberDoubleType, &result);
    }

    return result;
}

bool CFDefaultsGetBool(CFStringRef _key) noexcept
{
    return CFPreferencesGetAppBooleanValue(_key, kCFPreferencesCurrentApplication, nullptr);
}

std::optional<bool> CFDefaultsGetOptionalBool(CFStringRef _key) noexcept
{
    Boolean has = false;
    const Boolean v = CFPreferencesGetAppBooleanValue(_key, kCFPreferencesCurrentApplication, &has);
    if( !has )
        return {};
    return v != 0;
}

void CFDefaultsSetBool(CFStringRef _key, bool _value) noexcept
{
    CFPreferencesSetAppValue(_key, _value ? kCFBooleanTrue : kCFBooleanFalse, kCFPreferencesCurrentApplication);
}

double CFDefaultsGetDouble(CFStringRef _key) noexcept
{
    double result = 0.;

    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return result;
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = static_cast<CFNumberRef>(val);
        CFNumberGetValue(num, kCFNumberDoubleType, &result);
    }

    return result;
}

int CFDefaultsGetInt(CFStringRef _key) noexcept
{
    int result = 0.;

    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return result;
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = static_cast<CFNumberRef>(val);
        CFNumberGetValue(num, kCFNumberIntType, &result);
    }

    return result;
}

long CFDefaultsGetLong(CFStringRef _key) noexcept
{
    long result = 0.;

    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return result;
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFNumberGetTypeID() ) {
        CFNumberRef num = static_cast<CFNumberRef>(val);
        CFNumberGetValue(num, kCFNumberLongType, &result);
    }

    return result;
}

void CFDefaultsSetDouble(CFStringRef _key, double _value) noexcept
{
    CFNumberRef num = CFNumberCreate(nullptr, kCFNumberDoubleType, &_value);
    if( num == nullptr )
        return;
    auto release_val = at_scope_end([=] { CFRelease(num); });
    CFPreferencesSetAppValue(_key, num, kCFPreferencesCurrentApplication);
}

void CFDefaultsSetInt(CFStringRef _key, int _value) noexcept
{
    CFNumberRef num = CFNumberCreate(nullptr, kCFNumberIntType, &_value);
    if( num == nullptr )
        return;
    auto release_val = at_scope_end([=] { CFRelease(num); });
    CFPreferencesSetAppValue(_key, num, kCFPreferencesCurrentApplication);
}

void CFDefaultsSetLong(CFStringRef _key, long _value) noexcept
{
    CFNumberRef num = CFNumberCreate(nullptr, kCFNumberLongType, &_value);
    if( num == nullptr )
        return;
    auto release_val = at_scope_end([=] { CFRelease(num); });
    CFPreferencesSetAppValue(_key, num, kCFPreferencesCurrentApplication);
}

std::string CFDefaultsGetString(CFStringRef _key)
{
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return "";
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFStringGetTypeID() )
        return CFStringGetUTF8StdString(static_cast<CFStringRef>(val));

    return "";
}

std::optional<std::string> CFDefaultsGetOptionalString(CFStringRef _key)
{
    CFPropertyListRef val = CFPreferencesCopyAppValue(_key, kCFPreferencesCurrentApplication);
    if( !val )
        return {};
    auto release_val = at_scope_end([=] { CFRelease(val); });

    if( CFGetTypeID(val) == CFStringGetTypeID() )
        return CFStringGetUTF8StdString(static_cast<CFStringRef>(val));

    return {};
}

void CFDefaultsSetString(CFStringRef _key, const std::string &_value) noexcept
{
    CFStringRef str = CFStringCreateWithUTF8StdString(_value);
    if( !str )
        return;
    auto release_val = at_scope_end([=] { CFRelease(str); });
    CFPreferencesSetAppValue(_key, str, kCFPreferencesCurrentApplication);
}

void CFDefaultsRemoveValue(CFStringRef _key) noexcept
{
    CFPreferencesSetAppValue(_key, nullptr, kCFPreferencesCurrentApplication);
}

} // namespace nc::base
