#pragma once

#include <dispatch/dispatch.h>
#include <utility>
#include <atomic>
#include <chrono>

// synopsis

/** returns true if a current thread is actually a main thread (main queue). I.E. UI/Events thread. */
bool dispatch_is_main_queue() noexcept;

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

class DispatchGroup
{
public:
    enum Priority
    {
        High        = DISPATCH_QUEUE_PRIORITY_HIGH,
        Default     = DISPATCH_QUEUE_PRIORITY_DEFAULT,
        Low         = DISPATCH_QUEUE_PRIORITY_LOW,
        Background  = DISPATCH_QUEUE_PRIORITY_BACKGROUND
    };
    
    /**
     * Creates a dispatch group and gets a shared oncurrent queue.
     */
    DispatchGroup(Priority _priority = Default);
    
    /**
     * Will wait for completion before destruction.
     */
    ~DispatchGroup();
    
    /**
     * Run _block in group on queue with prioriry specified at construction time.
     */
    template <class T>
    void Run( T _f ) const;
    
    /**
     * Wait indefinitely until all tasks in group will finish.
     */
    void Wait() const noexcept;
    
    /**
     * Returnes amount of blocks currently running in this group.
     */
    unsigned Count() const noexcept;
    
private:
    DispatchGroup(const DispatchGroup&) = delete;
    void operator=(const DispatchGroup&) = delete;
    dispatch_queue_t m_Queue;
    dispatch_group_t m_Group;
    mutable std::atomic_uint m_Count{0};
};

// implementation details

template <class T>
inline void dispatch_async( dispatch_queue_t queue, T f )
{
    dispatch_async_f(queue,
                     new T( std::move(f) ),
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
                           new T( std::move(f) ),
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
                    new T( std::move(f) ),
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
                     new T( std::move(f) ),
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
                             new T( std::move(f) ),
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
                            new T( std::move(f) ),
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

template <class T>
inline void DispatchGroup::Run( T _f ) const
{
    using CT = std::pair<T, const DispatchGroup*>;
    auto *context = new CT( std::move(_f), this );
    ++m_Count;
    dispatch_group_async_f(m_Group,
                           m_Queue,
                           context,
                           [](void* _p) {
                               auto context = static_cast<CT*>(_p);
                               context->first();
                               --context->second->m_Count;
                               delete context;
                           });
}
