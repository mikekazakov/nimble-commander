// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <atomic>
#include <mutex>

namespace nc {

class spinlock
{
    std::atomic_flag __flag = ATOMIC_FLAG_INIT;
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

inline void spinlock::lock() noexcept
{
    while( __flag.test_and_set(std::memory_order_acquire) ) {
        yield();
    }
}

inline void spinlock::unlock() noexcept
{
    __flag.clear(std::memory_order_release);
}

} // namespace nc
