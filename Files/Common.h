//
//  Common.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#include "3rd_party/rapidjson/include/rapidjson/rapidjson.h"
#include "3rd_party/rapidjson/include/rapidjson/document.h"

//#include <Utility/

#include <Utility/PathManip.h>
#include <Utility/ObjCpp.h>

// TODO: remove it.
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

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);

#ifdef __OBJC__

void SyncMessageBoxNS(NSString *_ns_string);

typedef enum
{
    kTruncateAtStart,
    kTruncateAtMiddle,
    kTruncateAtEnd
} ETruncationType;
NSString *StringByTruncatingToWidth(NSString *str, float inWidth, ETruncationType truncationType, NSDictionary *attributes);

@interface NSPasteboard(SyntaxSugar)
+ (void) writeSingleString:(const char *)_s;
@end

NSError* ErrnoToNSError(int _error);
inline NSError* ErrnoToNSError() { return ErrnoToNSError(errno); }

#endif

inline bool strisdot(const char *s) noexcept { return s && s[0] == '.' && s[1] == 0; }
inline bool strisdotdot(const char *s) noexcept { return s && s[0] == '.' && s[1] == '.' && s[2] == 0; }
inline bool strisdotdot(const string &s) noexcept { return strisdotdot( s.c_str() ); }

inline string EnsureTrailingSlash(string _s)
{
    if( _s.empty() || _s.back() != '/' )
        _s.push_back('/');
    return _s;
}

#define __LOCK_GUARD_TOKENPASTE(x, y) x ## y
#define __LOCK_GUARD_TOKENPASTE2(x, y) __LOCK_GUARD_TOKENPASTE(x, y)
#define LOCK_GUARD(lock_object) int __LOCK_GUARD_TOKENPASTE2(__lock_guard_runs_, __LINE__) = 1; \
    for(std::lock_guard<decltype(lock_object)> __LOCK_GUARD_TOKENPASTE2(__lock_guard_, __LINE__)(lock_object); \
        __LOCK_GUARD_TOKENPASTE2(__lock_guard_runs_, __LINE__) != 0; \
        --__LOCK_GUARD_TOKENPASTE2(__lock_guard_runs_, __LINE__) \
        )
