// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/dispatch_cpp.h>
#include <cassert>
#include <fmt/core.h>
#include <pthread.h>
#include <stdexcept>

dispatch_queue::dispatch_queue(const char *label, bool concurrent)
    : m_queue(dispatch_queue_create(label, concurrent ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL))
{
}

dispatch_queue::~dispatch_queue()
{
    dispatch_release(m_queue);
}

dispatch_queue::dispatch_queue(const dispatch_queue &rhs) : m_queue(rhs.m_queue)
{
    dispatch_retain(m_queue);
}

dispatch_queue &dispatch_queue::operator=(const dispatch_queue &rhs)
{
    dispatch_release(m_queue);
    m_queue = rhs.m_queue;
    dispatch_retain(m_queue);
    return *this;
}

void dispatch_queue::async(dispatch_block_t block)
{
    dispatch_async(m_queue, block);
}

void dispatch_queue::sync(dispatch_block_t block)
{
    dispatch_sync(m_queue, block);
}

void dispatch_queue::apply(size_t iterations, void (^block)(size_t))
{
    dispatch_apply(iterations, m_queue, block);
}

void dispatch_queue::after(std::chrono::nanoseconds when, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, when.count()), m_queue, block);
}

namespace nc {

bool dispatch_is_main_queue() noexcept
{
    return pthread_main_np() != 0;
}

namespace base {

void dispatch_cpp_support::wrapped_call(void (*_call)(void *_ctx), void *_ctx) noexcept
{
    assert(_call);
    assert(_ctx);
    try {
        _call(_ctx);
    } catch( const std::exception &e ) {
        fmt::print(stderr, "Exception caught: {}\n", e.what());
    } catch( ... ) {
        fmt::print(stderr, "Caught an unhandled exception!\n");
    }
}

void dispatch_cpp_support::wrapped_call(void (*_call)(void *_ctx), void (*_delete)(void *_ctx), void *_ctx) noexcept
{
    assert(_call);
    assert(_delete);
    assert(_ctx);
    try {
        _call(_ctx);
    } catch( const std::exception &e ) {
        fmt::print(stderr, "Exception caught: {}\n", e.what());
    } catch( ... ) {
        fmt::print(stderr, "Caught an unhandled exception!\n");
    }
    _delete(_ctx);
}

} // namespace base

} // namespace nc
