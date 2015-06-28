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
inline void dispatch_async( dispatch_queue_t queue, T f )
{
    dispatch_async_f(queue,
                     new T( move(f) ),
                     [](void* _p) {
                         auto f = static_cast<T*>(_p);
                         (*f)();
                         delete f;
                     });
}

template <class T>
inline void dispatch_group_async( dispatch_group_t group, dispatch_queue_t queue, T f )
{
    dispatch_group_async_f(group,
                           queue,
                           new T( move(f) ),
                           [](void* _p) {
                               auto f = static_cast<T*>(_p);
                               (*f)();
                               delete f;
                           });
}

template <class T>
inline void dispatch_sync( dispatch_queue_t queue, T f )
{
    dispatch_sync_f(queue,
                    new T( move(f) ),
                    [](void* _p) {
                        auto f = static_cast<T*>(_p);
                        (*f)();
                        delete f;
                    });
}

template <class T>
inline void dispatch_apply( size_t iterations, dispatch_queue_t queue, T f )
{
    dispatch_apply_f(iterations,
                     queue,
                     &f,
                     [](void *_p, size_t _it) {
                         auto f = static_cast<T*>(_p);
                         (*f)(_it);
                     });
}

template <class T>
inline void dispatch_after( std::chrono::nanoseconds when, dispatch_queue_t queue, T f )
{
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, when.count()),
                     queue,
                     new T( move(f) ),
                     [](void* _p) {
                         auto f = static_cast<T*>(_p);
                         (*f)();
                         delete f;
                     });
}

template <class T>
inline void dispatch_barrier_async( dispatch_queue_t queue, T f )
{
    dispatch_barrier_async_f(queue,
                             new T( move(f) ),
                             [](void* _p) {
                                 auto f = static_cast<T*>(_p);
                                 (*f)();
                                 delete f;
                             });
}

template <class T>
inline void dispatch_barrier_sync( dispatch_queue_t queue, T f )
{
    dispatch_barrier_sync_f(queue,
                            new T( move(f) ),
                            [](void* _p) {
                                auto f = static_cast<T*>(_p);
                                (*f)();
                                delete f;
                            });
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
