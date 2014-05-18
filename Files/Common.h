//
//  Common.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#include "path_manip.h"


struct DialogResult
{
    enum
    {
        Unknown = 0,
        OK,
        Cancel,
        Create,
        Copy,
        Overwrite,
        Append,
        Skip,
        SkipAll,
        Rename,
        Retry,
        Apply,
        Delete
    };
};

// fs directory handling stuff
bool GetRealPath(const char *_path_in, char *_path_out);
bool GetDirectoryFromPath(const char *_path, char *_dir_out, size_t _dir_size); // get last directory from path
bool GetFirstAvailableDirectoryFromPath(char *_path);
/**
 * Returns a home directory path if form "/Users/migun". (without trailing slash)
 */
bool GetUserHomeDirectoryPath(char *_path);
bool IsDirectoryAvailableForBrowsing(const char *_path);

void EjectVolumeContainingPath(string _path); // a very simple function with no error feedback
bool IsVolumeContainingPathEjectable(const char *_path); // will return false on any errors

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);
void SyncMessageBoxNS(NSString *_ns_string);

extern uint64_t (*GetTimeInNanoseconds)();

inline CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const string &_s)
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s.c_str(),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

inline CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s)
{
    return CFStringCreateWithBytesNoCopy(0,
                                         (UInt8*)_s,
                                         strlen(_s),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

typedef enum
{
    kTruncateAtStart,
    kTruncateAtMiddle,
    kTruncateAtEnd
} ETruncationType;
NSString *StringByTruncatingToWidth(NSString *str, float inWidth, ETruncationType truncationType, NSDictionary *attributes);

struct MachTimeBenchmark
{
    uint64_t last;
    inline MachTimeBenchmark() : last(GetTimeInNanoseconds()) {};
    inline uint64_t Delta() const
    {
        return GetTimeInNanoseconds() - last;
    }
    inline void Reset()
    {
        uint64_t now = GetTimeInNanoseconds();
        NSLog(@"%llu\n", (now - last) / 1000000 );
        last = now;
    }
    inline void Reset(const char *_msg)
    {
        uint64_t now = GetTimeInNanoseconds();
        NSLog(@"%s %llu\n", _msg, (now - last) / 1000000 );
        last = now;
    }    
};

@interface NSView (Sugar)
- (void) setNeedsDisplay;
@end

@interface NSObject (MassObserving)
- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys;
- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys options:(NSKeyValueObservingOptions)options context:(void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys;
@end


@interface NSColor (MyAdditions)
- (CGColorRef) SafeCGColorRef;
+ (NSColor *)colorWithCGColorSafe:(CGColorRef)CGColor;
@end

@interface NSTimer (SafeTolerance)
- (void) SetSafeTolerance;
@end


@interface NSString(PerformanceAdditions)
+ (instancetype)stringWithUTF8StringNoCopy:(const char *)nullTerminatedCString;
+ (instancetype)stringWithUTF8StdStringNoCopy:(const string&)stdstring;
+ (instancetype)stringWithCharactersNoCopy:(const unichar *)characters length:(NSUInteger)length;
@end

@interface NSPasteboard(SyntaxSugar)
+ (void) writeSingleString:(const char *)_s;
@end

inline NSError* ErrnoToNSError() { return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; }
bool IsRunningUnitTesting();

NSString* FormHumanReadableSizeRepresentation6(uint64_t _sz);

inline bool dispatch_is_main_queue() { return [NSThread isMainThread]; }
inline void dispatch_to_main_queue(dispatch_block_t block) { dispatch_async(dispatch_get_main_queue(), block); }
inline bool strisdotdot(const char *s) { return s && s[0] == '.' && s[1] == '.' && s[2] == 0; }

/**
 * return max(lower, min(n, upper));
 */
template <typename T__>
inline T__ clip(const T__& n, const T__& lower, const T__& upper)
{
    return max(lower, min(n, upper));
}
