// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/debug.h>
#include <cassert>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>
#include <cstdlib>

namespace nc::base {

// Originated from Apple's Technical Q&A QA1361:
// Returns true if the current process is being debugged (either
// running under the debugger or has a debugger attached post facto).
bool AmIBeingDebugged() noexcept
{
    int mib[4];
    struct kinfo_proc info;
    size_t size;

    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.
    info.kp_proc.p_flag = 0;

    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    // Call sysctl.
    size = sizeof(info);
    [[maybe_unused]] const int junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, nullptr, 0);
    assert(junk == 0);

    // We're being debugged if the P_TRACED flag is set.
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}

static const bool g_IsSandboxed = std::getenv("APP_SANDBOX_CONTAINER_ID") != nullptr;

bool AmISandboxed() noexcept
{
    return g_IsSandboxed;
}

} // namespace nc::base
