// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <optional>

namespace nc::base {

bool CFDefaultsGetBool(CFStringRef _key) noexcept;
int CFDefaultsGetInt(CFStringRef _key) noexcept;
long CFDefaultsGetLong(CFStringRef _key) noexcept;
double CFDefaultsGetDouble(CFStringRef _key) noexcept;
std::string CFDefaultsGetString(CFStringRef _key);

std::optional<bool> CFDefaultsGetOptionalBool(CFStringRef _key) noexcept;
std::optional<int> CFDefaultsGetOptionalInt(CFStringRef _key) noexcept;
std::optional<long> CFDefaultsGetOptionalLong(CFStringRef _key) noexcept;
std::optional<double> CFDefaultsGetOptionalDouble(CFStringRef _key) noexcept;
std::optional<std::string> CFDefaultsGetOptionalString(CFStringRef _key);

void CFDefaultsSetBool(CFStringRef _key, bool _value) noexcept;
void CFDefaultsSetInt(CFStringRef _key, int _value) noexcept;
void CFDefaultsSetLong(CFStringRef _key, long _value) noexcept;
void CFDefaultsSetDouble(CFStringRef _key, double _value) noexcept;
void CFDefaultsSetString(CFStringRef _key, const std::string &_value) noexcept;

bool CFDefaultsHasValue(CFStringRef _key) noexcept;
void CFDefaultsRemoveValue(CFStringRef _key) noexcept;

} // namespace nc::base
