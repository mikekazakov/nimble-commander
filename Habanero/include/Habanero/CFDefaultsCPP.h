#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <experimental/optional>

std::experimental::optional<int>            CFDefaultsGetOptionalInt(CFStringRef _key);
std::experimental::optional<long>           CFDefaultsGetOptionalLong(CFStringRef _key);
double                                      CFDefaultsGetDouble(CFStringRef _key);
bool                                        CFDefaultsGetBool(CFStringRef _key);
std::experimental::optional<bool>           CFDefaultsGetOptionalBool(CFStringRef _key);
std::string                                 CFDefaultsGetString(CFStringRef _key);
std::experimental::optional<std::string>    CFDefaultsGetOptionalString(CFStringRef _key);


void CFDefaultsSetBool(CFStringRef _key, bool _value);
void CFDefaultsSetDouble(CFStringRef _key, double _value);
void CFDefaultsSetInt(CFStringRef _key, int _value);
void CFDefaultsSetLong(CFStringRef _key, long _value);
void CFDefaultsSetString(CFStringRef _key, const std::string &_value);


void CFDefaultsRemoveValue(CFStringRef _key);
