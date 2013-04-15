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
        Apply
    };
};

bool GetRealPath(const char *_path_in, char *_path_out);


struct MachTimeBenchmark
{
    uint64_t last;
    inline MachTimeBenchmark() : last(mach_absolute_time()) {};
    inline void Reset()
    {
        uint64_t now = mach_absolute_time();
        NSLog(@"%llu\n", (now - last) / 1000000 );
        last = now;
    }
};




