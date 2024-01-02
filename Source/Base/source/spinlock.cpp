// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/spinlock.h>
#include <mach/mach.h>

namespace nc {

void spinlock::yield() noexcept
{
    swtch_pri(0); // talking to Mach directly
}

} // namespace nc
