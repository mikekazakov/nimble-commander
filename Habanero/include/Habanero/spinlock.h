#pragma once

#include <mach/mach.h>
#include <atomic>
#include <mutex>

class spinlock
{
    std::atomic_flag __flag = ATOMIC_FLAG_INIT ;
public:
    inline void lock() noexcept {
        while( __flag.test_and_set(std::memory_order_acquire) ) {
            swtch_pri(0); // talking to Mach directly
        }
    }
    inline void unlock() noexcept {
        __flag.clear(std::memory_order_release);
    }
};

#define __LOCK_GUARD_TOKENPASTE(x, y) x ## y
#define __LOCK_GUARD_TOKENPASTE2(x, y) __LOCK_GUARD_TOKENPASTE(x, y)
#define LOCK_GUARD(lock_object) bool __LOCK_GUARD_TOKENPASTE2(__lock_guard_go_, __LINE__) = true; \
    for(std::lock_guard<decltype(lock_object)> __LOCK_GUARD_TOKENPASTE2(__lock_guard_, __LINE__)(lock_object); \
        __LOCK_GUARD_TOKENPASTE2(__lock_guard_go_, __LINE__); \
        __LOCK_GUARD_TOKENPASTE2(__lock_guard_go_, __LINE__) = false \
        )

template <typename _Lock, typename _Callable>
auto call_locked( _Lock &_lock, _Callable _callable )
{
    std::lock_guard<_Lock> guard(_lock);
    return _callable();
}
