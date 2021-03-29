// Copyright (C) 2015-2021 Michael G. Kazakov. Subject to GNU General Public License version 3.
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
    CFStringRef operator*() const noexcept;
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

inline CFStringRef CFString::operator*() const noexcept
{
    return p;
}

#ifdef __OBJC__
inline NSString *CFString::ns() const noexcept
{
    return (__bridge NSString *)p;
}
#endif

inline CFString::CFString(CFStringRef _str) noexcept : p(_str)
{
    if( p != nullptr )
        CFRetain(p);
}

inline CFString::CFString(const CFString &_rhs) noexcept : p(_rhs.p)
{
    if( p )
        CFRetain(p);
}

inline CFString::CFString(CFString &&_rhs) noexcept : p(_rhs.p)
{
    _rhs.p = nullptr;
}

inline CFString::~CFString()
{
    if( p )
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
