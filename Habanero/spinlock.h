#include <atomic>

class spinlock
{
    std::atomic_flag __flag = ATOMIC_FLAG_INIT ;
public:
    inline void lock() noexcept {
        while( __flag.test_and_set(std::memory_order_acquire) );
    }
    inline void unlock() noexcept {
        __flag.clear(std::memory_order_release);
    }
};
