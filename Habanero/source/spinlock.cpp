// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/spinlock.h>
#include <mach/mach.h>

void spinlock::yield() noexcept
{
    swtch_pri(0); // talking to Mach directly
}
