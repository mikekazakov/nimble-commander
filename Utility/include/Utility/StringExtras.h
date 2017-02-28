#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <Habanero/CFString.h>

#ifdef __OBJC__
    #include <Foundation/Foundation.h>
#endif

#ifdef __OBJC__

typedef enum
{
    kTruncateAtStart,
    kTruncateAtMiddle,
    kTruncateAtEnd
} ETruncationType;
NSString *StringByTruncatingToWidth(NSString *str, float inWidth, ETruncationType truncationType, NSDictionary *attributes);

@interface NSString(PerformanceAdditions)

- (const char *)fileSystemRepresentationSafe;
- (NSString*)stringByTrimmingLeadingWhitespace;
+ (instancetype)stringWithUTF8StdString:(const std::string&)stdstring;
+ (instancetype)stringWithUTF8StdStringFallback:(const std::string&)stdstring;
+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString;
+ (instancetype)stringWithUTF8StdStringNoCopy:(const std::string&)stdstring;
+ (instancetype)stringWithCharactersNoCopy:(const unichar *)characters length:(NSUInteger)length;

@end

#endif

