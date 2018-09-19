/* Copyright (c) 2015 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#include <mach/mach_time.h>
#include <mutex>
#include <Habanero/mach_time.h>

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
    call_once(once, []{
        mach_timebase_info(&info_data);
        if (info_data.denom == info_data.numer)
            GetTimeInNanoseconds = &mach_absolute_time;
        else
            GetTimeInNanoseconds = &GetTimeInNanosecondsScale;
    });
    return GetTimeInNanoseconds();
}

std::chrono::nanoseconds machtime() noexcept
{
    return std::chrono::nanoseconds( GetTimeInNanoseconds() );
}

MachTimeBenchmark::MachTimeBenchmark() noexcept:
    last(machtime())
{
};

std::chrono::nanoseconds MachTimeBenchmark::Delta() const
{
    return machtime() - last;
}

void MachTimeBenchmark::ResetNano(const char *_msg)
{
    auto now = machtime();
    printf("%s%llu\n", _msg, (now - last).count());
    last = now;
}

void MachTimeBenchmark::ResetMicro(const char *_msg)
{
    auto now = machtime();
    printf("%s%llu\n", _msg, std::chrono::duration_cast<std::chrono::microseconds>(now - last).count());
    last = now;
}

void MachTimeBenchmark::ResetMilli(const char *_msg)
{
    auto now = machtime();
    printf("%s%llu\n", _msg, std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count() );
    last = now;
}
