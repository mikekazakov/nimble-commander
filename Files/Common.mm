#include "Common.h"

// REMOVE THIS WHEN CLANG WILL HAVE IT INSIDE DEFAULT LIB
bad_optional_access::~bad_optional_access() noexcept = default;

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

void SyncMessageBoxUTF8(const char *_utf8_string)
{
    SyncMessageBoxNS([NSString stringWithUTF8String:_utf8_string]);
}

void SyncMessageBoxNS(NSString *_ns_string)
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: _ns_string];
    
    if(dispatch_is_main_queue())
        [alert runModal];
    else
        dispatch_sync(dispatch_get_main_queue(), ^{ [alert runModal]; } );
}

@implementation NSPasteboard(SyntaxSugar)
+ (void) writeSingleString:(const char *)_s
{
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb declareTypes:@[NSStringPboardType] owner:nil];
    [pb setString:[NSString stringWithUTF8String:_s] forType:NSStringPboardType];
}
@end

NSError* ErrnoToNSError(int _error)
{
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:_error userInfo:nil];
}
