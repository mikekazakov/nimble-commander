// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>
#include <Utility/StringExtras.h>
#include <Base/CFStackAllocator.h>

static void StringTruncateTo(NSMutableString *str, unsigned maxCharacters, ETruncationType truncationType)
{
    if( [str length] <= maxCharacters )
        return;

    NSRange replaceRange;
    replaceRange.length = [str length] - maxCharacters;

    switch( truncationType ) {
        case kTruncateAtStart:
            replaceRange.location = 0;
            break;

        case kTruncateAtMiddle:
            replaceRange.location = maxCharacters / 2;
            break;

        case kTruncateAtEnd:
            replaceRange.location = maxCharacters;
            break;
    }

    static NSString *sEllipsisString = nil;
    if( !sEllipsisString ) {
        const unichar ellipsisChar = 0x2026;
        sEllipsisString = [[NSString alloc] initWithCharacters:&ellipsisChar length:1];
    }

    [str replaceCharactersInRange:replaceRange withString:sEllipsisString];
}

static void
StringTruncateToWidth(NSMutableString *str, double maxWidth, ETruncationType truncationType, NSDictionary *attributes)
{
    // First check if we have to truncate at all.
    if( [str sizeWithAttributes:attributes].width <= maxWidth )
        return;

    // Essentially, we perform a binary search on the string length
    // which fits best into maxWidth.

    double width = maxWidth;
    int lo = 0;
    int hi = static_cast<int>(str.length);
    int mid;

    // Make a backup copy of the string so that we can restore it if we fail low.
    NSMutableString *const backup = [str mutableCopy];

    while( hi >= lo ) {
        mid = (hi + lo) / 2;

        // Cut to mid chars and calculate the resulting width
        StringTruncateTo(str, mid, truncationType);
        width = [str sizeWithAttributes:attributes].width;

        if( width > maxWidth ) {
            // Fail high - string is still to wide. For the next cut, we can simply
            // work on the already cut string, so we don't restore using the backup.
            hi = mid - 1;
        }
        else if( width == maxWidth ) {
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
    if( width != maxWidth )
        StringTruncateTo(str, hi, truncationType);
}

NSString *
StringByTruncatingToWidth(NSString *str, double inWidth, ETruncationType truncationType, NSDictionary *attributes)
{
    if( [str sizeWithAttributes:attributes].width > inWidth ) {
        NSMutableString *const mutableCopy = [str mutableCopy];
        StringTruncateToWidth(mutableCopy, inWidth, truncationType, attributes);
        return mutableCopy;
    }

    return str;
}

@implementation NSString (PerformanceAdditions)

- (const char *)fileSystemRepresentationSafe
{
    return self.length > 0 ? self.fileSystemRepresentation : "";
}

- (NSString *)stringByTrimmingLeadingWhitespace
{
    NSUInteger i = 0;
    static NSCharacterSet *cs = [NSCharacterSet whitespaceCharacterSet];

    while( i < self.length && [cs characterIsMember:[self characterAtIndex:i]] )
        i++;
    return [self substringFromIndex:i];
}

+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString
{
    auto cf_str = CFStringCreateWithBytesNoCopy(nullptr,
                                                reinterpret_cast<const UInt8 *>(nullTerminatedCString),
                                                std::strlen(nullTerminatedCString),
                                                kCFStringEncodingUTF8,
                                                false,
                                                kCFAllocatorNull);
    return static_cast<NSString *>(CFBridgingRelease(cf_str));
}
+ (instancetype)stringWithUTF8StdString:(const std::string &)stdstring
{
    auto cf_str = CFStringCreateWithBytes(
        nullptr, reinterpret_cast<const UInt8 *>(stdstring.c_str()), stdstring.length(), kCFStringEncodingUTF8, false);
    if( cf_str == nullptr )
        return nil;
    return static_cast<NSString *>(CFBridgingRelease(cf_str));
}

+ (instancetype)stringWithUTF8StdStringView:(std::string_view)_string_view
{
    auto cf_str = CFStringCreateWithBytes(nullptr,
                                          reinterpret_cast<const UInt8 *>(_string_view.data()),
                                          _string_view.length(),
                                          kCFStringEncodingUTF8,
                                          false);
    return static_cast<NSString *>(CFBridgingRelease(cf_str));
}

+ (instancetype)stringWithUTF8StdStringFallback:(const std::string &)stdstring
{
    if( auto s = CFStringCreateWithBytes(nullptr,
                                         reinterpret_cast<const UInt8 *>(stdstring.c_str()),
                                         stdstring.length(),
                                         kCFStringEncodingUTF8,
                                         false) )
        return static_cast<NSString *>(CFBridgingRelease(s));

    auto s = CFStringCreateWithBytes(nullptr,
                                     reinterpret_cast<const UInt8 *>(stdstring.c_str()),
                                     stdstring.length(),
                                     kCFStringEncodingMacRoman,
                                     false);
    return static_cast<NSString *>(CFBridgingRelease(s));
}

+ (instancetype)stringWithUTF8StdStringNoCopy:(const std::string &)stdstring
{
    auto cf_str = CFStringCreateWithBytesNoCopy(nullptr,
                                                reinterpret_cast<const UInt8 *>(stdstring.c_str()),
                                                stdstring.length(),
                                                kCFStringEncodingUTF8,
                                                false,
                                                kCFAllocatorNull);
    return static_cast<NSString *>(CFBridgingRelease(cf_str));
}

+ (instancetype)stringWithCharactersNoCopy:(const unichar *)characters length:(NSUInteger)length
{
    auto cf_str = CFStringCreateWithCharactersNoCopy(nullptr, characters, length, kCFAllocatorNull);
    return static_cast<NSString *>(CFBridgingRelease(cf_str));
}

@end

bool LowercaseEqual(std::string_view _s1, std::string_view _s2) noexcept
{
    if( _s1.data() == nullptr && _s2.data() == nullptr )
        return true;
    if( _s1.data() == nullptr || _s2.data() == nullptr )
        return false;

    const nc::base::CFStackAllocator st_alloc;

    const auto s1 = CFStringCreateWithBytesNoCopy(st_alloc,
                                                  reinterpret_cast<const UInt8 *>(_s1.data()),
                                                  _s1.length(),
                                                  kCFStringEncodingUTF8,
                                                  false,
                                                  kCFAllocatorNull);
    if( !s1 )
        return false;

    const auto s2 = CFStringCreateWithBytesNoCopy(st_alloc,
                                                  reinterpret_cast<const UInt8 *>(_s2.data()),
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
