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

CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const string &_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept;
CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept;

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);

/** returns a value from NSTemporaryDirectory, once captured. Contains a path with a trailing slash. */
const string &AppTemporaryDirectory() noexcept;

/** returns relative Mach time in nanoseconds using mach_absolute_time. */
nanoseconds machtime() noexcept;

/** returns true if a current thread is actually a main thread (main queue). I.E. UI/Events thread. */
bool dispatch_is_main_queue() noexcept;

/** syntax sugar for dispatch_async_f(dispatch_get_main_queue(), ...) call. */
template <class T>
inline void dispatch_to_main_queue(T _block)
{
    dispatch_async(dispatch_get_main_queue(), move(_block) );
}

/** syntax sugar for dispatch_async_f(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ...) call. */
template <class T>
inline void dispatch_to_default(T _block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), move(_block) );
}

/** syntax sugar for dispatch_async_f(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ...) call. */
template <class T>
inline void dispatch_to_background(T _block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), move(_block) );
}

/** syntax sugar for dispatch_after_f(..., dispatch_get_main_queue(), _block) call. */
template <class T>
inline void dispatch_to_main_queue_after(nanoseconds _delay, T _block)
{
    dispatch_after(_delay, dispatch_get_main_queue(), move(_block));
}

/** if current thread is main - just execute a block. otherwise - dispatch it asynchronously to main thread. */
void dispatch_or_run_in_main_queue(function<void()> _block);

struct MachTimeBenchmark
{
    MachTimeBenchmark() noexcept;
    nanoseconds Delta() const;
    void ResetNano (const char *_msg = "");
    void ResetMicro(const char *_msg = "");
    void ResetMilli(const char *_msg = "");
private:
    nanoseconds last;
};

#ifdef __OBJC__

/**
 * Returns a _T_ class object if _from_ can be converted to it.
 * If _from_ can't be converted to _T_ - returns nil.
 * If _from_ is nil - returns nil.
 */
template<typename T>
inline T* objc_cast(id from) noexcept {
    if ( [from isKindOfClass:[T class]] )
        return static_cast<T*>(from);
    return nil;
}

void SyncMessageBoxNS(NSString *_ns_string);

typedef enum
{
    kTruncateAtStart,
    kTruncateAtMiddle,
    kTruncateAtEnd
} ETruncationType;
NSString *StringByTruncatingToWidth(NSString *str, float inWidth, ETruncationType truncationType, NSDictionary *attributes);

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
- (void) setSafeTolerance;
@end

@interface NSString(PerformanceAdditions)
- (const char *)fileSystemRepresentationSafe;
- (NSString*)stringByTrimmingLeadingWhitespace;
+ (instancetype)stringWithUTF8StdString:(const string&)stdstring;
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

NSError* ErrnoToNSError(int _error);
inline NSError* ErrnoToNSError() { return ErrnoToNSError(errno); }

#endif

inline bool strisdotdot(const char *s) { return s && s[0] == '.' && s[1] == '.' && s[2] == 0; }
inline bool strisdotdot(const string &s) { return s.length() == 2 && s[0] == '.' && s[1] == '.'; }

/**
 * return max(lower, min(n, upper));
 */
template <typename T__>
inline T__ clip(const T__& n, const T__& lower, const T__& upper)
{
    return max(lower, min(n, upper));
}
