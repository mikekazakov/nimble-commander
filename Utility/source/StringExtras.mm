// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>
#include <Utility/StringExtras.h>
#include <Habanero/CFStackAllocator.h>

using namespace std;

static void StringTruncateTo(NSMutableString *str, unsigned maxCharacters, ETruncationType truncationType)
{
    if ([str length] <= maxCharacters)
        return;
    
    NSRange replaceRange;
    replaceRange.length = [str length] - maxCharacters;
    
    switch (truncationType) {
        case kTruncateAtStart:
            replaceRange.location = 0;
            break;
            
        case kTruncateAtMiddle:
            replaceRange.location = maxCharacters / 2;
            break;
            
        case kTruncateAtEnd:
            replaceRange.location = maxCharacters;
            break;
            
        default:
#if DEBUG
            NSLog(@"Unknown truncation type in stringByTruncatingTo::");
#endif
            replaceRange.location = maxCharacters;
            break;
    }
    
    static NSString* sEllipsisString = nil;
    if (!sEllipsisString) {
        unichar ellipsisChar = 0x2026;
        sEllipsisString = [[NSString alloc] initWithCharacters:&ellipsisChar length:1];
    }
    
    [str replaceCharactersInRange:replaceRange withString:sEllipsisString];
}

static void StringTruncateToWidth(NSMutableString *str, float maxWidth, ETruncationType truncationType, NSDictionary *attributes)
{
    // First check if we have to truncate at all.
    if ([str sizeWithAttributes:attributes].width <= maxWidth)
        return;
    
    // Essentially, we perform a binary search on the string length
    // which fits best into maxWidth.
    
    float width = maxWidth;
    int lo = 0;
    int hi = (int)[str length];
    int mid;
    
    // Make a backup copy of the string so that we can restore it if we fail low.
    NSMutableString *backup = [str mutableCopy];
    
    while (hi >= lo) {
        mid = (hi + lo) / 2;
        
        // Cut to mid chars and calculate the resulting width
        StringTruncateTo(str, mid, truncationType);
        width = [str sizeWithAttributes:attributes].width;
        
        if (width > maxWidth) {
            // Fail high - string is still to wide. For the next cut, we can simply
            // work on the already cut string, so we don't restore using the backup.
            hi = mid - 1;
        }
        else if (width == maxWidth) {
            // Perfect match, abort the search.
            break;
        }
        else {
            // Fail low - we cut off too much. Restore the string before cutting again.
            lo = mid + 1;
            [str setString:backup];
        }
    }
    // Perform the final cut (unless this was already a perfect match).
    if (width != maxWidth)
        StringTruncateTo(str, hi, truncationType);
}

NSString *StringByTruncatingToWidth(NSString *str, float inWidth, ETruncationType truncationType, NSDictionary *attributes)
{
    if ([str sizeWithAttributes:attributes].width > inWidth)
    {
        NSMutableString *mutableCopy = [str mutableCopy];
        StringTruncateToWidth(mutableCopy, inWidth, truncationType, attributes);
        return mutableCopy;
    }
    
    return str;
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

+ (instancetype)stringWithUTF8StdStringFallback:(const std::string&)stdstring
{
    if( auto s = CFStringCreateWithBytes(0,
                                         (UInt8*)stdstring.c_str(),
                                         stdstring.length(),
                                         kCFStringEncodingUTF8,
                                         false) )
        return (NSString*) CFBridgingRelease(s);


    auto s = CFStringCreateWithBytes(0,
                                     (UInt8*)stdstring.c_str(),
                                     stdstring.length(),
                                     kCFStringEncodingMacRoman,
                                     false);
    return (NSString*) CFBridgingRelease(s);
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

bool LowercaseEqual(std::experimental::string_view _s1,
                    std::experimental::string_view _s2 ) noexcept
{
    if( _s1.data() == nullptr && _s2.data() == nullptr )
        return true;
    if( _s1.data() == nullptr || _s2.data() == nullptr )
        return false;

    CFStackAllocator st_alloc;
    
    const auto s1 =  CFStringCreateWithBytesNoCopy(st_alloc.Alloc(),
                                                   (const UInt8*)_s1.data(),
                                                   _s1.length(),
                                                   kCFStringEncodingUTF8,
                                                   false,
                                                   kCFAllocatorNull);
    if( !s1 )
        return false;

    const auto s2 =  CFStringCreateWithBytesNoCopy(st_alloc.Alloc(),
                                                   (const UInt8*)_s2.data(),
                                                   _s2.length(),
                                                   kCFStringEncodingUTF8,
                                                   false,
                                                   kCFAllocatorNull);
    if( !s2 ) {
        CFRelease(s1);
        return false;
    }
    
    const auto r = CFStringCompare(s1, s2, kCFCompareCaseInsensitive);
    
    CFRelease(s1);
    CFRelease(s2);
    
    return r == kCFCompareEqualTo;
}
