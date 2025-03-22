// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/spinlock.h>
#include <mach/mach.h>

namespace nc {

void spinlock::yield() noexcept
{
    swtch_pri(0); // talking to Mach directly
}

void spinlock::lock() noexcept
{
    while( m_Flag.test_and_set(std::memory_order_acquire) ) {
        yield();
    }
}

void spinlock::unlock() noexcept
{
    m_Flag.clear(std::memory_order_release);
}

} // namespace nc
