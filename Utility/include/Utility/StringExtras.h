#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <experimental/string_view>

#ifdef __OBJC__
    #include <Foundation/Foundation.h>
#endif

CFStringRef CFStringCreateWithUTF8StringNoCopy(std::experimental::string_view _s) noexcept;
CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const std::string &_s) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept;

#ifdef __OBJC__

@interface NSString(PerformanceAdditions)

- (const char *)fileSystemRepresentationSafe;
- (NSString*)stringByTrimmingLeadingWhitespace;
+ (instancetype)stringWithUTF8StdString:(const std::string&)stdstring;
+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString;
+ (instancetype)stringWithUTF8StdStringNoCopy:(const std::string&)stdstring;
+ (instancetype)stringWithCharactersNoCopy:(const unichar *)characters length:(NSUInteger)length;

@end

#endif