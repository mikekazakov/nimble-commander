// Copyright (C) 2023-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <stdint.h>
#include <compare>
#include <functional>
#include <vector>
#include <iosfwd>
#include <dispatch/dispatch.h>

namespace nc::term {

// A callback will triggered in a background queue whenever a process with _root_pid or any of its children either fork
// or exec or exit. If multiple events happens close to each other they might be coalesced into a single callback with
// the total amount of events of each type happened since last callback.
class ChildrenTracker
{
public:
    struct Event {
        // How many fork events happened
        unsigned forks = 0;

        // How many exec events happened
        unsigned execs = 0;

        // How many exit events happened
        unsigned exits = 0;

        auto operator<=>(const Event &) const noexcept = default;
    };

    ChildrenTracker(int _root_pid, std::function<void(Event _event)> _cb);
    ChildrenTracker(const ChildrenTracker &) = delete;
    ~ChildrenTracker();
    ChildrenTracker &operator=(const ChildrenTracker &) = delete;

    // Returns the root PID for which this tracker is tracking the children.
    [[nodiscard]] int pid() const;

    // Returns the number of process the tracker is currently aware of, in various states.
    // This number might be larger than the number of processes currently actively tracked,
    // since it includes the zombies tracker aware of.
    [[nodiscard]] size_t KnownProcesses() const;

private:
    struct ProcessInfo {
        pid_t pid = -1;
        uint32_t status = 0; // SIDL | SRUN | SSLEEP | SSTOP | SZOMB
    };

    void Drain();
    int m_RootPID = -1;
    int m_KQ = -1;
    dispatch_queue_t m_Queue = nullptr;
    dispatch_source_t m_Source = nullptr;
    std::function<void(Event _event)> m_Callback;
    std::vector<ProcessInfo> m_Tracked;
};

std::ostream &operator<<(std::ostream &_os, const ChildrenTracker::Event &_event);

} // namespace nc::term
