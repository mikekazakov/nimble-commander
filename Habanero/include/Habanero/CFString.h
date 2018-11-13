/* Copyright (c) 2015-2018 Michael G. Kazakov
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
#include <string_view>

class CFString
{
public:
    CFString() noexcept = default;
    CFString(CFStringRef _str) noexcept;
    CFString(const std::string &_str) noexcept;
    CFString(const std::string &_str, CFStringEncoding _encoding) noexcept;
    CFString(const char *_str) noexcept;
    CFString(const CFString &_rhs) noexcept;
    CFString(CFString &&_rhs) noexcept;
    ~CFString();
    
    const CFString &operator=(const CFString &_rhs) noexcept;
    const CFString &operator=(CFString &&_rhs) noexcept;
    
    operator bool() const noexcept;
    CFStringRef operator *() const noexcept;
#ifdef __OBJC__
    NSString *ns() const noexcept;
#endif

private:
    CFStringRef p = nullptr;
};

std::string CFStringGetUTF8StdString(CFStringRef _str);
CFStringRef CFStringCreateWithUTF8StdString(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(std::string_view _s) noexcept;
CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept;

inline CFString::operator bool() const noexcept
{
    return p != nullptr;
}

inline CFStringRef CFString::operator *() const noexcept
{
    return p;
}

#ifdef __OBJC__
inline NSString *CFString::ns() const noexcept
{
    return (__bridge NSString*)p;
}
#endif

inline CFString::CFString(CFStringRef _str) noexcept:
    p(_str)
{
    if( p != nullptr )
        CFRetain(p);
}

inline CFString::CFString(const CFString &_rhs) noexcept:
    p( _rhs.p )
{
    if( p )
        CFRetain(p);
}

inline CFString::CFString(CFString &&_rhs) noexcept:
    p( _rhs.p )
{
    _rhs.p = nullptr;
}

inline CFString::~CFString()
{
    if(p)
        CFRelease(p);
}

inline const CFString &CFString::operator=(const CFString &_rhs) noexcept
{
    if( &_rhs == this )
        return *this;
    if( p )
        CFRelease(p);
    p = _rhs.p;
    if( p )
        CFRetain(p);
    return *this;
}

inline const CFString &CFString::operator=(CFString &&_rhs) noexcept
{
    if( &_rhs == this )
        return *this;    
    if( p )
        CFRelease(p);
    p = _rhs.p;
    _rhs.p = nullptr;
    return *this;
}
