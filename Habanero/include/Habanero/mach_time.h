//
//  mach_time.h
//  Habanero
//
//  Created by Michael G. Kazakov on 24/08/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#pragma once

#include <chrono>

/** returns relative Mach time in nanoseconds using mach_absolute_time. */
std::chrono::nanoseconds machtime() noexcept;

struct MachTimeBenchmark
{
    MachTimeBenchmark() noexcept;
    std::chrono::nanoseconds Delta() const;
    void ResetNano (const char *_msg = "");
    void ResetMicro(const char *_msg = "");
    void ResetMilli(const char *_msg = "");
private:
    std::chrono::nanoseconds last;
};
