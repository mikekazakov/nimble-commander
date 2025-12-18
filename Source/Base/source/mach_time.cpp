// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/mach_time.h>
#include <fmt/format.h>
#include <mach/mach_time.h>
#include <mutex>

namespace nc::base {

static uint64_t InitGetTimeInNanoseconds();
static uint64_t (*GetTimeInNanoseconds)() = InitGetTimeInNanoseconds;
static mach_timebase_info_data_t info_data;

static uint64_t GetTimeInNanosecondsScale()
{
    return mach_absolute_time() * info_data.numer / info_data.denom;
}

static uint64_t InitGetTimeInNanoseconds()
{
    static std::once_flag once;
    call_once(once, [] {
        mach_timebase_info(&info_data);
        if( info_data.denom == info_data.numer )
            GetTimeInNanoseconds = &mach_absolute_time;
        else
            GetTimeInNanoseconds = &GetTimeInNanosecondsScale;
    });
    return GetTimeInNanoseconds();
}

std::chrono::nanoseconds machtime() noexcept
{
    return std::chrono::nanoseconds(GetTimeInNanoseconds());
}

MachTimeBenchmark::MachTimeBenchmark() noexcept : last(machtime()) {};

std::chrono::nanoseconds MachTimeBenchmark::Delta() const
{
    return machtime() - last;
}

void MachTimeBenchmark::ResetNano(const char *_msg)
{
    auto now = machtime();
    fmt::println("{}{}", _msg, (now - last).count());
    last = now;
}

void MachTimeBenchmark::ResetMicro(const char *_msg)
{
    auto now = machtime();
    fmt::println("{}{}", _msg, std::chrono::duration_cast<std::chrono::microseconds>(now - last).count());
    last = now;
}

void MachTimeBenchmark::ResetMilli(const char *_msg)
{
    auto now = machtime();
    fmt::println("{}{}", _msg, std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count());
    last = now;
}

} // namespace nc::base
