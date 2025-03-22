// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <atomic>
#include <mutex>

namespace nc {

class spinlock
{
    std::atomic_flag m_Flag;
    static void yield() noexcept;

public:
    void lock() noexcept;
    void unlock() noexcept;
};

template <typename _Lock, typename _Callable>
auto call_locked(_Lock &_lock, _Callable _callable)
{
    std::lock_guard<_Lock> guard(_lock);
    return _callable();
}

} // namespace nc
