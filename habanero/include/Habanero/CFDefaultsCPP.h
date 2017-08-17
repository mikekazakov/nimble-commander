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
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <experimental/optional>

bool        CFDefaultsGetBool(CFStringRef _key);
int         CFDefaultsGetInt(CFStringRef _key);
long        CFDefaultsGetLong(CFStringRef _key);
double      CFDefaultsGetDouble(CFStringRef _key);
std::string CFDefaultsGetString(CFStringRef _key);

std::experimental::optional<bool>           CFDefaultsGetOptionalBool(CFStringRef _key);
std::experimental::optional<int>            CFDefaultsGetOptionalInt(CFStringRef _key);
std::experimental::optional<long>           CFDefaultsGetOptionalLong(CFStringRef _key);
std::experimental::optional<double>         CFDefaultsGetOptionalDouble(CFStringRef _key);
std::experimental::optional<std::string>    CFDefaultsGetOptionalString(CFStringRef _key);

void CFDefaultsSetBool(CFStringRef _key, bool _value);
void CFDefaultsSetInt(CFStringRef _key, int _value);
void CFDefaultsSetLong(CFStringRef _key, long _value);
void CFDefaultsSetDouble(CFStringRef _key, double _value);
void CFDefaultsSetString(CFStringRef _key, const std::string &_value);

void CFDefaultsRemoveValue(CFStringRef _key);
