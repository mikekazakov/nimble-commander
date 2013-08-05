//
//  Common.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

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

struct MenuTags
{
    enum
    {
        PanelViewShortMode  = 1000,
        PanelViewMediumMode = 1001,
        PanelViewFullMode   = 1002,
        PanelViewWideMode   = 1003,
        PanelSortByName     = 1010,
        PanelSortByExt      = 1011,
        PanelSortByMTime    = 1012,
        PanelSortBySize     = 1013,
        PanelSortByBTime    = 1014,
        PanelSortViewHidden = 1020,
        PanelSortSepDirs    = 1021,
        PanelSortCaseSensitive = 1022,
        PanelSortNumeric    = 1023
    };
};

// fs directory handling stuff
bool GetRealPath(const char *_path_in, char *_path_out);
bool GetDirectoryFromPath(const char *_path, char *_dir_out, size_t _dir_size);
bool GetFirstAvailableDirectoryFromPath(char *_path);
bool GetUserHomeDirectoryPath(char *_path);
bool IsDirectoryAvailableForBrowsing(const char *_path);
int  GetFileSystemRootFromPath(const char *_path, char *_root); // return 0 on sucess, or errno value on error
void EjectVolumeContainingPath(const char *_path); // a very simple function with no error feedback
bool IsVolumeContainingPathEjectable(const char *_path); // will return false on any errors

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);
void SyncMessageBoxNS(NSString *_ns_string);

extern uint64_t (*GetTimeInNanoseconds)();
void InitGetTimeInNanoseconds();

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

@interface NSObject (MassObserving)
- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys options:(NSKeyValueObservingOptions)options context:(void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys;
@end


@interface NSColor (MyAdditions)
- (CGColorRef) SafeCGColorRef;
@end
