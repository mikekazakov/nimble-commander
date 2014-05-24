#import <mach/mach_time.h>
#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <sys/attr.h>
#import <sys/vnode.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <unistd.h>
#import <dirent.h>
#import <pwd.h>
#import <DiskArbitration/DiskArbitration.h>
#import "NativeFSManager.h"
#import "Common.h"
#import "sysinfo.h"
#import "AppDelegate.h"

static uint64_t InitGetTimeInNanoseconds();
uint64_t (*GetTimeInNanoseconds)() = InitGetTimeInNanoseconds;

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
static uint64_t GetTimeInNanosecondsScale()
{
    return mach_absolute_time()*info_data.numer/info_data.denom;
}

static uint64_t InitGetTimeInNanoseconds()
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mach_timebase_info(&info_data);
        if (info_data.denom == info_data.numer)
            GetTimeInNanoseconds = &mach_absolute_time;
        else
            GetTimeInNanoseconds = &GetTimeInNanosecondsScale;
    });
    return GetTimeInNanoseconds();
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

bool IsDirectoryAvailableForBrowsing(const char *_path)
{
    DIR *dirp = opendir(_path);
    if(dirp == 0)
        return false;
    closedir(dirp);
    return true;
}

void EjectVolumeContainingPath(const string &_path)
{
    string path = _path;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(auto volume = NativeFSManager::Instance().VolumeFromPath(path))
        {
            DASessionRef session = DASessionCreate(kCFAllocatorDefault);
            CFURLRef url = (__bridge CFURLRef)volume->verbose.url;
            DADiskRef disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url);
            if(disk)
            {
                DADiskUnmount(disk, kDADiskUnmountOptionDefault, NULL, NULL);
                CFRelease(disk);
            }
            CFRelease(session);
        }
    });
}

bool IsVolumeContainingPathEjectable(const string &_path)
{
    auto volume = NativeFSManager::Instance().VolumeFromPath(_path);
    
    if(!volume)
        return false;
    
    static string net("/net"), dev("/dev"), home("/home");
    
    if(volume->mounted_at_path == net ||
       volume->mounted_at_path == dev ||
       volume->mounted_at_path == home )
        return false;
    
    return  volume->mount_flags.ejectable   == true  ||
            volume->mount_flags.removable   == true  ||
            volume->mount_flags.internal    == false ||
            volume->mount_flags.local       == false ;
}

@implementation NSObject (MassObserving)
- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys
{
    for(NSString *s: keys)
        [self addObserver:observer forKeyPath:s options:0 context:nil];
}

- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys options:(NSKeyValueObservingOptions)options context:(void *)context
{
    for(NSString *s: keys)
        [self addObserver:observer forKeyPath:s options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys
{
    for(NSString *s: keys)
        [self removeObserver:observer forKeyPath:s];
}
@end

@implementation NSColor (MyAdditions)
- (CGColorRef) SafeCGColorRef
{
    const NSInteger numberOfComponents = [self numberOfComponents];
    CGFloat components[numberOfComponents];
    CGColorSpaceRef colorSpace = [[self colorSpace] CGColorSpace];
        
    [self getComponents:(CGFloat *)&components];
        
    return CGColorCreate(colorSpace, components);
}

+ (NSColor *)colorWithCGColorSafe:(CGColorRef)CGColor
{
    if (CGColor == NULL) return nil;
    return [NSColor colorWithCIColor:[CIColor colorWithCGColor:CGColor]];
}

@end

@implementation NSTimer (SafeTolerance)
- (void) SetSafeTolerance
{
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9)
        [self setTolerance:[self timeInterval]/10.];
}
@end

@implementation NSString(PerformanceAdditions)

+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString
{
    return (NSString*) CFBridgingRelease(CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)nullTerminatedCString,
                                         strlen(nullTerminatedCString),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull));
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


@implementation NSView (Sugar)
- (void) setNeedsDisplay
{
    if(dispatch_is_main_queue())
        [self setNeedsDisplay:TRUE];
    else
        dispatch_to_main_queue( ^{ [self setNeedsDisplay:TRUE]; } );
}
@end

@implementation NSPasteboard(SyntaxSugar)
+ (void) writeSingleString:(const char *)_s
{
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb declareTypes:@[NSStringPboardType] owner:nil];
    [pb setString:[NSString stringWithUTF8String:_s] forType:NSStringPboardType];
}
@end

NSString* FormHumanReadableSizeRepresentation6(uint64_t _sz)
{
    if(_sz < 1000000) // bytes
        return [NSString stringWithFormat:@"%6llu", _sz];
    else if(_sz < 9999lu * 1024lu) // kilobytes
    {
        uint64_t div = 1024lu;
        uint64_t res = _sz / div;
        return [NSString stringWithFormat:@"%4llu K", res + (_sz - res * div) / (div/2)];
    }
    else if(_sz < 9999lu * 1048576lu) // megabytes
    {
        uint64_t div = 1048576lu;
        uint64_t res = _sz / div;
        return [NSString stringWithFormat:@"%4llu M", res + (_sz - res * div) / (div/2)];
    }
    else if(_sz < 9999lu * 1073741824lu) // gigabytes
    {
        uint64_t div = 1073741824lu;
        uint64_t res = _sz / div;
        return [NSString stringWithFormat:@"%4llu G", res + (_sz - res * div) / (div/2)];
    }
    else if(_sz < 9999lu * 1099511627776lu) // terabytes
    {
        uint64_t div = 1099511627776lu;
        uint64_t res = _sz / div;
        return [NSString stringWithFormat:@"%4llu T", res + (_sz - res * div) / (div/2)];
    }
    else if(_sz < 9999lu * 1125899906842624lu) // petabytes
    {
        uint64_t div = 1125899906842624lu;
        uint64_t res = _sz / div;
        return [NSString stringWithFormat:@"%4llu P", res + (_sz - res * div) / (div/2)];
    }
    return @"";
}

bool IsRunningUnitTesting()
{
    return ((AppDelegate*)[NSApplication.sharedApplication delegate]).isRunningTests;
}
