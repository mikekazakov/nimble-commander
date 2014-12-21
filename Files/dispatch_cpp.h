#pragma once

#include <dispatch/dispatch.h>
#include <functional>
#include <utility>

// synopsis

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



// implementation details

namespace __dispatch_cpp {
    typedef std::function<void()>       __lambda_exec;
    typedef std::function<void(size_t)> __lambda_apply;
    void __dispatch_cpp_exec_delete_lambda(void*);
    void __dispatch_cpp_apply_lambda(void*, size_t);
}

template <class T>
inline void dispatch_async( dispatch_queue_t queue, T f )
{
    dispatch_async_f(queue,
                     new __dispatch_cpp::__lambda_exec( std::move(f) ),
                     __dispatch_cpp::__dispatch_cpp_exec_delete_lambda);
}

template <class T>
inline void dispatch_sync( dispatch_queue_t queue, T f )
{
    dispatch_sync_f(queue,
                    new __dispatch_cpp::__lambda_exec( std::move(f) ),
                    __dispatch_cpp::__dispatch_cpp_exec_delete_lambda);
}

template <class T>
inline void dispatch_apply( size_t iterations, dispatch_queue_t queue, T f )
{
    __dispatch_cpp::__lambda_apply l( std::move(f) );
    dispatch_apply_f(iterations,
                     queue,
                     &l,
                     __dispatch_cpp::__dispatch_cpp_apply_lambda);
}

template <class T>
inline void dispatch_after( std::chrono::nanoseconds when, dispatch_queue_t queue, T f )
{
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, when.count()),
                     queue,
                     new __dispatch_cpp::__lambda_exec( std::move(f) ),
                     __dispatch_cpp::__dispatch_cpp_exec_delete_lambda);
}

template <class T>
inline void dispatch_barrier_async( dispatch_queue_t queue, T f )
{
    dispatch_barrier_async_f(queue,
                             new __dispatch_cpp::__lambda_exec( std::move(f) ),
                             __dispatch_cpp::__dispatch_cpp_exec_delete_lambda);
}

template <class T>
inline void dispatch_barrier_sync( dispatch_queue_t queue, T f )
{
    dispatch_barrier_sync_f(queue,
                            new __dispatch_cpp::__lambda_exec( std::move(f) ),
                            __dispatch_cpp::__dispatch_cpp_exec_delete_lambda);
}
