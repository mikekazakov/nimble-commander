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
bool GetDirectoryFromPath(const char *_path, char *_dir_out, size_t _dir_size); // get last directory from path

bool IsDirectoryAvailableForBrowsing(const char *_path);

void EjectVolumeContainingPath(const string &_path); // a very simple function with no error feedback
bool IsVolumeContainingPathEjectable(const string &_path); // will return false on any errors

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);
void SyncMessageBoxNS(NSString *_ns_string);

nanoseconds machtime() noexcept;

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
    nanoseconds last;
    inline MachTimeBenchmark() : last(machtime()) {};
    inline nanoseconds Delta() const
    {
        return machtime() - last;
    }
    inline void ResetNano(const char *_msg = "")
    {
        auto now = machtime();
        NSLog(@"%s%llu\n", _msg, (now - last).count());
        last = now;
    }
    inline void ResetMicro(const char *_msg = "")
    {
        auto now = machtime();
        NSLog(@"%s%llu\n", _msg, duration_cast<microseconds>(now - last).count());
        last = now;
    }
    inline void ResetMilli(const char *_msg = "")
    {
        auto now = machtime();
        NSLog(@"%s%llu\n", _msg, duration_cast<milliseconds>(now - last).count() );
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
- (CGColorRef) copyCGColorRefSafe;
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

@interface NSMenu(Hierarchical)
- (NSMenuItem *)itemWithTagHierarchical:(NSInteger)tag;
- (NSMenuItem *)itemContainingItemWithTagHierarchical:(NSInteger)tag;
@end

inline NSError* ErrnoToNSError() { return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; }
bool IsRunningUnitTesting();

NSString* FormHumanReadableSizeRepresentation6(uint64_t _sz);

inline bool dispatch_is_main_queue() { return [NSThread isMainThread]; }
inline void dispatch_to_main_queue(dispatch_block_t block) { dispatch_async(dispatch_get_main_queue(), block); }
inline void dispatch_or_run_in_main_queue(dispatch_block_t block) {
    dispatch_is_main_queue() ? block() : dispatch_to_main_queue(block);
}

inline bool strisdotdot(const char *s) { return s && s[0] == '.' && s[1] == '.' && s[2] == 0; }

/**
 * return max(lower, min(n, upper));
 */
template <typename T__>
inline T__ clip(const T__& n, const T__& lower, const T__& upper)
{
    return max(lower, min(n, upper));
}
