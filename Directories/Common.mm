#import "Common.h"
#import <mach/mach_time.h>

uint64_t (*GetTimeInNanoseconds)() = nullptr;

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


// ask FS about real file path - case sensitive etc
// also we're getting rid of symlinks - it will be a real file
// return path with trailing slash
bool GetRealPath(const char *_path_in, char *_path_out)
{
    int tfd = open(_path_in, O_RDONLY);
    if(tfd == -1)
        return false;
    int ret = fcntl(tfd, F_GETPATH, _path_out);
    close(tfd);
    if(ret == -1)
        return false;
    if( _path_out[strlen(_path_out)-1] != '/' )
        strcat(_path_out, "/");
    return true;
}

bool GetDirectoryFromPath(const char *_path, char *_dir_out, size_t _dir_size)
{
    const char *second_sep = strrchr(_path, '/');
    if (!second_sep) return false;
    
    // Path contains single / in the beginning.
    if (second_sep == _path)
    {
        assert(_dir_size >= 2);
        _dir_out[0] = '/';
        _dir_out[1] = 0;
        return true;
    }
    
    // Searching for the second separator.
    const char *first_sep = second_sep - 1;
    for (; first_sep != _path && *first_sep != '/'; --first_sep);
    
    if (*first_sep != '/')
    {
        // Peculiar situation. Path contains only on /, and it is in the middle of the path.
        // Assume that directory name is part of the path located to the left of the /.
        first_sep = _path - 1;
    }
    
    size_t len = second_sep - first_sep - 1;
    assert(len + 1 <= _dir_size);
    memcpy(_dir_out, first_sep + 1, len);
    _dir_out[len + 1] = 0;
    
    return true;
}

static mach_timebase_info_data_t info_data;
uint64_t GetTimeInNanosecondsScale()
{
    return mach_absolute_time()*info_data.numer/info_data.denom;
}

void InitGetTimeInNanoseconds()
{
    mach_timebase_info(&info_data);
    if (info_data.denom == info_data.numer)
        GetTimeInNanoseconds = &mach_absolute_time;
    else
        GetTimeInNanoseconds = &GetTimeInNanosecondsScale;
}

void SyncMessageBoxUTF8(const char *_utf8_string)
{
    SyncMessageBoxNS([NSString stringWithUTF8String:_utf8_string]);
}

void SyncMessageBoxNS(NSString *_ns_string)
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: _ns_string];
    
    if(dispatch_get_current_queue() == dispatch_get_main_queue())
        [alert runModal];
    else
        dispatch_sync(dispatch_get_main_queue(), ^{ [alert runModal]; } );
}


