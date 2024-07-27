// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <dispatch/dispatch.h>
#include <utility>
#include <chrono>
#include <assert.h>

namespace nc {

// returns true if a current thread is actually a main thread (main queue). I.E. UI/Events thread.
bool dispatch_is_main_queue() noexcept;

namespace base {

struct dispatch_cpp_support {
    // catches any exceptions and prints them to stderr
    static void wrapped_call(void (*_call)(void *_ctx), void *_ctx) noexcept;
    static void wrapped_call(void (*_call)(void *_ctx), void (*_delete)(void *_ctx), void *_ctx) noexcept;
};

} // namespace base

} // namespace nc

// effectively assert( dispatch_is_main_queue() )
#define dispatch_assert_main_queue() assert(nc::dispatch_is_main_queue());

// effectively assert( !dispatch_is_main_queue() )
#define dispatch_assert_background_queue() assert(!nc::dispatch_is_main_queue());

template <class T>
void dispatch_async(dispatch_queue_t queue, T f);

template <class T>
void dispatch_sync(dispatch_queue_t queue, T f);

template <class T>
void dispatch_apply(size_t iterations, dispatch_queue_t queue, const T &f);

template <class T>
void dispatch_apply(size_t iterations, const T &f);

template <class T>
void dispatch_after(std::chrono::nanoseconds when, dispatch_queue_t queue, T f);

template <class T>
void dispatch_barrier_async(dispatch_queue_t queue, T f);

template <class T>
void dispatch_barrier_sync(dispatch_queue_t queue, T f);

/** syntax sugar for dispatch_async_f(dispatch_get_main_queue(), ...) call. */
template <class T>
void dispatch_to_main_queue(T _block);

/** syntax sugar for dispatch_async_f(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ...) call. */
template <class T>
void dispatch_to_default(T _block);

/** syntax sugar for dispatch_async_f(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ...) call. */
template <class T>
void dispatch_to_background(T _block);

/** syntax sugar for dispatch_after_f(..., dispatch_get_main_queue(), _block) call. */
template <class T>
void dispatch_to_main_queue_after(std::chrono::nanoseconds _delay, T _block);

/** syntax sugar for dispatch_after_f(..., dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), _block)
 * call. */
template <class T>
void dispatch_to_background_after(std::chrono::nanoseconds _delay, T _block);

/** if current thread is main - just execute a block. otherwise - dispatch it asynchronously to main thread. */
template <class T>
void dispatch_or_run_in_main_queue(T _block);

class dispatch_queue
{
public:
    dispatch_queue(const char *label = nullptr, bool concurrent = false);
    dispatch_queue(const dispatch_queue &rhs);
    ~dispatch_queue();
    dispatch_queue &operator=(const dispatch_queue &rhs);

    void async(dispatch_block_t block);
    template <class T>
    void async(T f);

    void sync(dispatch_block_t block);
    template <class T>
    void sync(T f);

    void apply(size_t iterations, void (^block)(size_t));
    template <class T>
    void apply(size_t iterations, T f);

    void after(std::chrono::nanoseconds when, dispatch_block_t block);
    template <class T>
    void after(std::chrono::nanoseconds when, T f);

private:
    dispatch_queue_t m_queue;
};

// implementation details

template <class T>
inline void dispatch_async(dispatch_queue_t _queue, T _f)
{
    dispatch_async_f(_queue, new T(std::move(_f)), [](void *_p) {
        nc::base::dispatch_cpp_support::wrapped_call(
            [](void *_p) { (*static_cast<T *>(_p))(); }, [](void *_p) { delete static_cast<T *>(_p); }, _p);
    });
}

template <class T>
void dispatch_group_async(dispatch_group_t _group, dispatch_queue_t _queue, T _f)
{
    dispatch_group_async_f(_group, _queue, new T(std::move(_f)), [](void *_p) {
        nc::base::dispatch_cpp_support::wrapped_call(
            [](void *_p) { (*static_cast<T *>(_p))(); }, [](void *_p) { delete static_cast<T *>(_p); }, _p);
    });
}

template <class T>
void dispatch_sync(dispatch_queue_t _queue, T _f)
{
    dispatch_sync_f(_queue, &_f, [](void *_p) {
        nc::base::dispatch_cpp_support::wrapped_call([](void *_p) { (*static_cast<T *>(_p))(); }, _p);
    });
}

template <class T>
void dispatch_apply(size_t _iterations, dispatch_queue_t _queue, const T &_f)
{
    dispatch_apply_f(_iterations, _queue, const_cast<void *>(static_cast<const void *>(&_f)), [](void *_p, size_t _it) {
        auto f = static_cast<const T *>(_p);
        (*f)(_it);
    });
}

template <class T>
void dispatch_apply(size_t _iterations, const T &_f)
{
    dispatch_apply_f(
        _iterations, DISPATCH_APPLY_AUTO, const_cast<void *>(static_cast<const void *>(&_f)), [](void *_p, size_t _it) {
            auto f = static_cast<const T *>(_p);
            (*f)(_it);
        });
}

template <class T>
void dispatch_after(std::chrono::nanoseconds _when, dispatch_queue_t _queue, T _f)
{
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, _when.count()), _queue, new T(std::move(_f)), [](void *_p) {
        nc::base::dispatch_cpp_support::wrapped_call(
            [](void *_p) { (*static_cast<T *>(_p))(); }, [](void *_p) { delete static_cast<T *>(_p); }, _p);
    });
}

template <class T>
void dispatch_barrier_async(dispatch_queue_t _queue, T _f)
{
    dispatch_barrier_async_f(_queue, new T(std::move(_f)), [](void *_p) {
        nc::base::dispatch_cpp_support::wrapped_call(
            [](void *_p) { (*static_cast<T *>(_p))(); }, [](void *_p) { delete static_cast<T *>(_p); }, _p);
    });
}

template <class T>
void dispatch_barrier_sync(dispatch_queue_t _queue, T _f)
{
    dispatch_barrier_sync_f(_queue, new T(std::move(_f)), [](void *_p) {
        nc::base::dispatch_cpp_support::wrapped_call(
            [](void *_p) { (*static_cast<T *>(_p))(); }, [](void *_p) { delete static_cast<T *>(_p); }, _p);
    });
}

template <class T>
void dispatch_to_main_queue(T _block)
{
    dispatch_async(dispatch_get_main_queue(), std::move(_block));
}

template <class T>
void dispatch_to_default(T _block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), std::move(_block));
}

template <class T>
void dispatch_to_background(T _block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), std::move(_block));
}

template <class T>
void dispatch_to_main_queue_after(std::chrono::nanoseconds _delay, T _block)
{
    dispatch_after(_delay, dispatch_get_main_queue(), std::move(_block));
}

template <class T>
void dispatch_to_background_after(std::chrono::nanoseconds _delay, T _block)
{
    dispatch_after(_delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), std::move(_block));
}

template <class T>
void dispatch_or_run_in_main_queue(T _block)
{
    nc::dispatch_is_main_queue() ? _block() : dispatch_to_main_queue(std::move(_block));
}

template <class T>
void dispatch_queue::async(T f)
{
    dispatch_async(m_queue, std::move(f));
}

template <class T>
void dispatch_queue::sync(T f)
{
    dispatch_sync(m_queue, std::move(f));
}

template <class T>
void dispatch_queue::apply(size_t iterations, T f)
{
    dispatch_apply(iterations, m_queue, std::move(f));
}

template <class T>
void dispatch_queue::after(std::chrono::nanoseconds when, T f)
{
    dispatch_after(when, m_queue, std::move(f));
}

inline void dispatch_queue::async(dispatch_block_t block)
{
    dispatch_async(m_queue, block);
}

inline void dispatch_queue::sync(dispatch_block_t block)
{
    dispatch_sync(m_queue, block);
}

inline void dispatch_queue::apply(size_t iterations, void (^block)(size_t))
{
    dispatch_apply(iterations, m_queue, block);
}

inline void dispatch_queue::after(std::chrono::nanoseconds when, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, when.count()), m_queue, block);
}
