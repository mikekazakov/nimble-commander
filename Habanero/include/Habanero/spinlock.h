// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <atomic>
#include <mutex>
#include <mach/mach.h>

class spinlock
{
    std::atomic_flag __flag = ATOMIC_FLAG_INIT ;
public:
    void lock() noexcept;
    void unlock() noexcept;
};

#define __LOCK_GUARD_TOKENPASTE(x, y) x ## y
#define __LOCK_GUARD_TOKENPASTE2(x, y) __LOCK_GUARD_TOKENPASTE(x, y)
#define LOCK_GUARD(lock_object)\
if( std::lock_guard<decltype(lock_object)> __LOCK_GUARD_TOKENPASTE2(__lock_guard_, __LINE__)(lock_object); false) { } \
else


template <typename _Lock, typename _Callable>
auto call_locked( _Lock &_lock, _Callable _callable )
{
    std::lock_guard<_Lock> guard(_lock);
    return _callable();
}

inline void spinlock::lock() noexcept
{
    while( __flag.test_and_set(std::memory_order_acquire) ) {
        swtch_pri(0); // talking to Mach directly
    }
}

inline void spinlock::unlock() noexcept
{
    __flag.clear(std::memory_order_release);
}
