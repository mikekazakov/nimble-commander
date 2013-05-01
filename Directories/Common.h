//
//  Common.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#include <mach/mach_time.h>

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
    };
};

bool GetRealPath(const char *_path_in, char *_path_out);
bool GetDirectoryFromPath(const char *_path, char *_dir_out, size_t _dir_size);

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
};




