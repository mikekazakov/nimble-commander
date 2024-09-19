// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DateTimeParser.h"
#include <Base/CFStackAllocator.h>
#include <mutex>

namespace nc::vfs::webdav {

static time_t ParseUnlocked(CFDateFormatterRef _fmt, const char *_date_time);

time_t DateTimeFromRFC1123(const char *_date_time)
{
    static const auto formatter = [] {
        auto locale = CFLocaleCreate(kCFAllocatorDefault, CFSTR("en_US"));
        auto tz = CFTimeZoneCreateWithTimeIntervalFromGMT(nullptr, 0);
        auto f = CFDateFormatterCreate(kCFAllocatorDefault, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
        CFDateFormatterSetFormat(f, CFSTR("EEE',' dd MMM yyyy HH':'mm':'ss z"));
        CFDateFormatterSetProperty(f, kCFDateFormatterTimeZone, tz);
        CFRelease(tz);
        CFRelease(locale);
        return f;
    }();
    [[clang::no_destroy]] static std::mutex formatter_lock;
    const auto lock = std::lock_guard{formatter_lock};
    return ParseUnlocked(formatter, _date_time);
}

time_t DateTimeFromRFC850(const char *_date_time)
{
    static const auto formatter = [] {
        auto locale = CFLocaleCreate(kCFAllocatorDefault, CFSTR("en_US"));
        auto tz = CFTimeZoneCreateWithTimeIntervalFromGMT(nullptr, 0);
        auto f = CFDateFormatterCreate(kCFAllocatorDefault, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
        CFDateFormatterSetFormat(f, CFSTR("EEEE',' dd'-'MMM'-'yy HH':'mm':'ss z"));
        CFDateFormatterSetProperty(f, kCFDateFormatterTimeZone, tz);
        CFRelease(tz);
        CFRelease(locale);
        return f;
    }();
    [[clang::no_destroy]] static std::mutex formatter_lock;
    const auto lock = std::lock_guard{formatter_lock};
    return ParseUnlocked(formatter, _date_time);
}

time_t DateTimeFromASCTime(const char *_date_time)
{
    static const auto formatter = [] {
        auto locale = CFLocaleCreate(kCFAllocatorDefault, CFSTR("en_US"));
        auto tz = CFTimeZoneCreateWithTimeIntervalFromGMT(nullptr, 0);
        auto f = CFDateFormatterCreate(kCFAllocatorDefault, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
        CFDateFormatterSetFormat(f, CFSTR("EEE MMM d HH':'mm':'ss yyyy"));
        CFDateFormatterSetProperty(f, kCFDateFormatterTimeZone, tz);
        CFRelease(tz);
        CFRelease(locale);
        return f;
    }();
    [[clang::no_destroy]] static std::mutex formatter_lock;
    const auto lock = std::lock_guard{formatter_lock};
    return ParseUnlocked(formatter, _date_time);
}

time_t DateTimeFromRFC3339(const char *_date_time)
{
    static const auto formatter = [] {
        auto locale = CFLocaleCreate(kCFAllocatorDefault, CFSTR("en_US"));
        auto tz = CFTimeZoneCreateWithTimeIntervalFromGMT(nullptr, 0);
        auto f = CFDateFormatterCreate(kCFAllocatorDefault, locale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
        CFDateFormatterSetFormat(f, CFSTR("yyyy-MM-dd'T'HH:mm:ssZZZZZ"));
        CFDateFormatterSetProperty(f, kCFDateFormatterTimeZone, tz);
        CFRelease(tz);
        CFRelease(locale);
        return f;
    }();
    [[clang::no_destroy]] static std::mutex formatter_lock;
    const auto lock = std::lock_guard{formatter_lock};
    return ParseUnlocked(formatter, _date_time);
}

static time_t ParseUnlocked(CFDateFormatterRef _fmt, const char *_date_time)
{
    const base::CFStackAllocator alloc;
    time_t result = -1;

    const auto str = CFStringCreateWithCString(alloc, _date_time, kCFStringEncodingUTF8);
    if( str ) {
        const auto date = CFDateFormatterCreateDateFromString(alloc, _fmt, str, nullptr);
        if( date ) {
            result = time_t(CFDateGetAbsoluteTime(date) + kCFAbsoluteTimeIntervalSince1970);
            CFRelease(date);
        }
        CFRelease(str);
    }
    return result;
}

} // namespace nc::vfs::webdav
