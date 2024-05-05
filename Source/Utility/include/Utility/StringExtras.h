// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <string_view>
#include <Base/CFString.h>

#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

#ifdef __OBJC__

typedef enum {
    kTruncateAtStart,
    kTruncateAtMiddle,
    kTruncateAtEnd
} ETruncationType;
NSString *
StringByTruncatingToWidth(NSString *str, double inWidth, ETruncationType truncationType, NSDictionary *attributes);

@interface NSString (PerformanceAdditions)

- (const char *)fileSystemRepresentationSafe;
- (NSString *)stringByTrimmingLeadingWhitespace;
+ (instancetype)stringWithUTF8StdString:(const std::string &)stdstring;
+ (instancetype)stringWithUTF8StdStringView:(std::string_view)_string_view;
+ (instancetype)stringWithUTF8StdStringFallback:(const std::string &)stdstring;
+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString;
+ (instancetype)stringWithUTF8StdStringNoCopy:(const std::string &)stdstring;
+ (instancetype)stringWithCharactersNoCopy:(const unichar *)characters length:(NSUInteger)length;

@end

#endif

bool LowercaseEqual(std::string_view _s1, std::string_view _s2) noexcept;
