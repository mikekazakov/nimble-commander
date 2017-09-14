/* Copyright (c) 2015-2016 Michael G. Kazakov
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
#ifdef __OBJC__
    #import <Foundation/Foundation.h>
#endif

#include <string>
#include <experimental/string_view>

class CFString
{
public:
    CFString();
    CFString(const std::string &_str);
    CFString(const std::string &_str, CFStringEncoding _encoding);
    CFString(const char *_str);
    CFString(const CFString &_rhs);
    CFString(CFString &&_rhs);
    ~CFString();
    
    const CFString &operator=(const CFString &_rhs) noexcept;
    const CFString &operator=(CFString &&_rhs) noexcept;
    
    inline              operator bool() const noexcept { return p != nullptr; }
    inline CFStringRef  operator    *() const noexcept { return p; }
#ifdef __OBJC__
    inline NSString               *ns() const noexcept { return (__bridge NSString*)p; }
#endif

private:
    CFStringRef p;
};

std::string CFStringGetUTF8StdString(CFStringRef _str);
CFStringRef CFStringCreateWithUTF8StdString(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(std::experimental::string_view _s) noexcept;
CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept;
