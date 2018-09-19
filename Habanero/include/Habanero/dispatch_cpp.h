/* Copyright (c) 2014-2016 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#pragma once

#include <dispatch/dispatch.h>
#include <utility>
#include <atomic>
#include <chrono>
#include <iostream>
#include <assert.h>

// synopsis

/** returns true if a current thread is actually a main thread (main queue).
 I.E. UI/Events thread. */
#define dispatch_is_main_queue() \
    (pthread_main_np() != 0)

/** effectively assert( dispatch_is_main_queue() ) */
#define dispatch_assert_main_queue() \
    assert( dispatch_is_main_queue() );

/** effectively assert( !dispatch_is_main_queue() ) */
#define dispatch_assert_background_queue() \
    assert( !dispatch_is_main_queue() );

template <class T>
void dispatch_async( dispatch_queue_t queue, T f );

template <class T>
void dispatch_sync( dispatch_queue_t queue, T f );

template <class T>
void dispatch_apply( size_t iterations, dispatch_queue_t queue, T f );

template <class T>
void dispatch_after( std::chrono::nanoseconds when, dispatch_queue_t queue, T f );

template <class T>
void dispatch_barrier_async( dispatch_queue_t queue, T f );

template <class T>
void dispatch_barrier_sync( dispatch_queue_t queue, T f );

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

/** syntax sugar for dispatch_after_f(..., dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), _block) call. */
template <class T>
void dispatch_to_background_after(std::chrono::nanoseconds _delay, T _block);

/** if current thread is main - just execute a block. otherwise - dispatch it asynchronously to main thread. */
template <class T>
void dispatch_or_run_in_main_queue(T _block);

class dispatch_queue
{
public:
    dispatch_queue( const char *label = nullptr, bool concurrent = false );
    dispatch_queue( const dispatch_queue& rhs );
    ~dispatch_queue();
    const dispatch_queue &operator=( const dispatch_queue& rhs );

    void async( dispatch_block_t block );
    template <class T>
    void async( T f );

    void sync( dispatch_block_t block );
    template <class T>
    void sync( T f );
  
    void apply( size_t iterations, void (^block)(size_t) );
    template <class T>
    void apply( size_t iterations, T f );

    void after( std::chrono::nanoseconds when, dispatch_block_t block );
    template <class T>
    void after( std::chrono::nanoseconds when, T f );
    
private:
    dispatch_queue_t m_queue;
};

// implementation details

template <class T>
inline void dispatch_async( dispatch_queue_t _queue, T _f )
{
    dispatch_async_f(_queue,
                     new T( std::move(_f) ),
                     [](void* _p) {
                         auto f = static_cast<T*>(_p);
                         (*f)();
                         delete f;
                     });
}

template <class T>
inline void dispatch_group_async( dispatch_group_t _group, dispatch_queue_t _queue, T _f )
{
    dispatch_group_async_f(_group,
                           _queue,
                           new T( std::move(_f) ),
                           [](void* _p) {
                               auto f = static_cast<T*>(_p);
                               (*f)();
                               delete f;
                           });
}

template <class T>
inline void dispatch_sync( dispatch_queue_t _queue, T _f )
{
    dispatch_sync_f(_queue,
                    &_f,
                    [](void* _p) {
                        auto f = static_cast<T*>(_p);
                        (*f)();
                    });
}

template <class T>
inline void dispatch_apply( size_t _iterations, dispatch_queue_t _queue, T _f )
{
    dispatch_apply_f(_iterations,
                     _queue,
                     &_f,
                     [](void *_p, size_t _it) {
                         auto f = static_cast<T*>(_p);
                         (*f)(_it);
                     });
}

template <class T>
inline void dispatch_after( std::chrono::nanoseconds _when, dispatch_queue_t _queue, T _f )
{
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, _when.count()),
                     _queue,
                     new T( std::move(_f) ),
                     [](void* _p) {
                         auto f = static_cast<T*>(_p);
                         try
                         {
                             (*f)();
                         }
                         catch(std::exception &e)
                         {
                             std::cerr << "Exception caught: " << e.what() << std::endl;
                         }
                         catch(std::exception *e)
                         {
                             std::cerr << "Exception caught: " << e->what() << std::endl;
                         }
                         catch(...)
                         {
                             std::cerr << "Caught an unhandled exception!" << std::endl;
                         }
                         delete f;
                     });
}

template <class T>
inline void dispatch_barrier_async( dispatch_queue_t _queue, T _f )
{
    dispatch_barrier_async_f(_queue,
                             new T( std::move(_f) ),
                             [](void* _p) {
                                 auto f = static_cast<T*>(_p);
                                 (*f)();
                                 delete f;
                             });
}

template <class T>
inline void dispatch_barrier_sync( dispatch_queue_t _queue, T _f )
{
    dispatch_barrier_sync_f(_queue,
                            new T( std::move(_f) ),
                            [](void* _p) {
                                auto f = static_cast<T*>(_p);
                                (*f)();
                                delete f;
                            });
}

template <class T>
inline void dispatch_to_main_queue(T _block)
{
    dispatch_async(dispatch_get_main_queue(), std::move(_block) );
}

template <class T>
inline void dispatch_to_default(T _block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), std::move(_block) );
}

template <class T>
inline void dispatch_to_background(T _block)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), std::move(_block) );
}

template <class T>
inline void dispatch_to_main_queue_after(std::chrono::nanoseconds _delay, T _block)
{
    dispatch_after(_delay, dispatch_get_main_queue(), std::move(_block));
}

template <class T>
inline void dispatch_to_background_after(std::chrono::nanoseconds _delay, T _block)
{
    dispatch_after(_delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), std::move(_block));
}

template <class T>
inline void dispatch_or_run_in_main_queue(T _block)
{
    dispatch_is_main_queue() ? _block() : dispatch_to_main_queue(std::move(_block));
}

template <class T>
inline void dispatch_queue::async( T f )
{
    dispatch_async( m_queue, std::move(f) );
}

template <class T>
inline void dispatch_queue::sync( T f )
{
    dispatch_sync( m_queue, std::move(f) );
}

template <class T>
inline void dispatch_queue::apply( size_t iterations, T f )
{
    dispatch_apply( iterations, m_queue, std::move(f) );
}

template <class T>
inline void dispatch_queue::after( std::chrono::nanoseconds when, T f )
{
    dispatch_after(when, m_queue, std::move(f) );
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

inline void dispatch_queue::after( std::chrono::nanoseconds when, dispatch_block_t block )
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, when.count()), m_queue, block);
}
