#include <Utility/StringExtras.h>

using namespace std;
using namespace std::experimental;

CFStringRef CFStringCreateWithUTF8StringNoCopy(string_view _s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.data(),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.c_str(),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         strlen(_s),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         _len,
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.c_str(),
                                         _s.length(),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
    
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         strlen(_s),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         _len,
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}


@implementation NSString(PerformanceAdditions)

- (const char *)fileSystemRepresentationSafe
{
    return self.length > 0 ? self.fileSystemRepresentation : "";
}

- (NSString*)stringByTrimmingLeadingWhitespace
{
    NSInteger i = 0;
    static NSCharacterSet *cs = [NSCharacterSet whitespaceCharacterSet];
    
    while( i < self.length && [cs characterIsMember:[self characterAtIndex:i]] )
        i++;
    return [self substringFromIndex:i];
}

+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString
{
    return (NSString*) CFBridgingRelease(CFStringCreateWithBytesNoCopy(0,
                                                                       (UInt8*)nullTerminatedCString,
                                                                       strlen(nullTerminatedCString),
                                                                       kCFStringEncodingUTF8,
                                                                       false,
                                                                       kCFAllocatorNull));
}

+ (instancetype)stringWithUTF8StdString:(const string&)stdstring
{
    return (NSString*) CFBridgingRelease(CFStringCreateWithBytes(0,
                                                                 (UInt8*)stdstring.c_str(),
                                                                 stdstring.length(),
                                                                 kCFStringEncodingUTF8,
                                                                 false));
}

+ (instancetype)stringWithUTF8StdStringNoCopy:(const string&)stdstring
{
    return (NSString*) CFBridgingRelease(CFStringCreateWithBytesNoCopy(0,
                                                                       (UInt8*)stdstring.c_str(),
                                                                       stdstring.length(),
                                                                       kCFStringEncodingUTF8,
                                                                       false,
                                                                       kCFAllocatorNull));
}

+ (instancetype)stringWithCharactersNoCopy:(const unichar *)characters length:(NSUInteger)length
{
    return (NSString*) CFBridgingRelease(CFStringCreateWithCharactersNoCopy(0,
                                                                            characters,
                                                                            length,
                                                                            kCFAllocatorNull));
}

@end