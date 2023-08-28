// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <stdint.h>
#include <compare>
#include <functional>
#include <vector>
#include <dispatch/dispatch.h>

namespace nc::term {

// A callback will triggered in a background queue whenever a process with _root_pid or any of its children either fork
// or exec or exit.
class ChildrenTracker
{
public:
    ChildrenTracker(int _root_pid, std::function<void()> _cb);
    ChildrenTracker(const ChildrenTracker &) = delete;
    ~ChildrenTracker();
    ChildrenTracker &operator=(const ChildrenTracker &) = delete;

    int pid() const;

private:
    void Drain();
    int m_RootPID = -1;
    int m_KQ = -1;
    dispatch_queue_t m_Queue = nullptr;
    dispatch_source_t m_Source = nullptr;
    std::function<void()> m_Callback;
    std::vector<pid_t> m_Tracked;
};

} // namespace nc::term
