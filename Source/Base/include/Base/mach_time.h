// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <chrono>

namespace nc::base {

/** returns relative Mach time in nanoseconds using mach_absolute_time. */
std::chrono::nanoseconds machtime() noexcept;

struct MachTimeBenchmark {
    MachTimeBenchmark() noexcept;
    std::chrono::nanoseconds Delta() const;
    void ResetNano(const char *_msg = "");
    void ResetMicro(const char *_msg = "");
    void ResetMilli(const char *_msg = "");

private:
    std::chrono::nanoseconds last;
};

} // namespace nc::base
