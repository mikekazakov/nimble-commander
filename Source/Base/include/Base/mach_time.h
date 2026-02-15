// Copyright (C) 2015-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <chrono>
#include <string_view>

namespace nc::base {

/** returns relative Mach time in nanoseconds using mach_absolute_time. */
std::chrono::nanoseconds machtime() noexcept;

struct MachTimeBenchmark {
    MachTimeBenchmark() noexcept;
    [[nodiscard]] std::chrono::nanoseconds Delta() const;
    void ResetNano(std::string_view _msg = {});
    void ResetMicro(std::string_view _msg = {});
    void ResetMilli(std::string_view _msg = {});

private:
    std::chrono::nanoseconds last;
};

} // namespace nc::base
