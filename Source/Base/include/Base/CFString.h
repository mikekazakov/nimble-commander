// Copyright (C) 2015-2023 Michael G. Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#include "CFPtr.h"
#include <string>
#include <string_view>

namespace nc::base {

class CFString
{
public:
    CFString() noexcept = default;
    CFString(CFStringRef _str) noexcept;
    CFString(std::string_view _str, CFStringEncoding _encoding = kCFStringEncodingUTF8) noexcept;
    CFString(const char *_str, CFStringEncoding _encoding = kCFStringEncodingUTF8) noexcept;

    operator bool() const noexcept;
    CFStringRef operator*() const noexcept;
#ifdef __OBJC__
    NSString *ns() const noexcept;
#endif

private:
    nc::base::CFPtr<CFStringRef> p;
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
    return static_cast<bool>(p);
}

inline CFStringRef CFString::operator*() const noexcept
{
    return p.get();
}

#ifdef __OBJC__
inline NSString *CFString::ns() const noexcept
{
    return (__bridge NSString *)p.get();
}
#endif

inline CFString::CFString(CFStringRef _str) noexcept : p(_str)
{
}

} // namespace nc::base
