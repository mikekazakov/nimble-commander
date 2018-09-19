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

#include <memory>
#include <functional>
#include <atomic>
#include "dispatch_cpp.h"
#include "spinlock.h"

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
     * Run _f in group on queue with prioriry specified at construction time.
     * This might be a lambda, or a function<void()> or anything else callable.
     */
    template <class T>
    void Run( T _f ) const;
    
    /**
     * Wait indefinitely until all tasks in group will finish.
     */
    void Wait() const noexcept;
    
    /**
     * Returns amount of blocks currently running in this group.
     */
    int Count() const noexcept;
    
    /**
     * Actually returns Count() == 0. Just a syntax sugar.
     */
    bool Empty() const noexcept;
    
    /**
     * Set a callback function which will be called when Count() becomes zero.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~DispatchGroup().
     * Reentrant.
     */
    void SetOnDry( std::function<void()> _cb );
    
    /**
     * Set a callback function which will be called when Count() becomes non-zero for first time.
     * Might be called from undefined background thread.
     * Reentrant.
     */
    void SetOnWet( std::function<void()> _cb );
    
    /**
     * Set a callback function which will be called every time Count() changes.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~DispatchGroup().
     * Reentrant.
     */
    void SetOnChange( std::function<void()> _cb );
    
private:
    void Increment() const;
    void Decrement() const;
    void FireDry() const;
    void FireWet() const;
    void FireChange() const;
    
    DispatchGroup(const DispatchGroup&) = delete;
    void operator=(const DispatchGroup&) = delete;
    dispatch_queue_t m_Queue;
    dispatch_group_t m_Group;
    mutable std::atomic_int m_Count{0};
    mutable spinlock m_CallbackLock;
    std::shared_ptr< std::function<void()> > m_OnDry;
    std::shared_ptr< std::function<void()> > m_OnWet;
    std::shared_ptr< std::function<void()> > m_OnChange;
};

template <class T>
inline void DispatchGroup::Run( T _f ) const
{
    using CT = std::pair<T, const DispatchGroup*>;
    Increment();
    dispatch_group_async_f(m_Group,
                           m_Queue,
                           new CT( std::move(_f), this ),
                           [](void* _p) {
                               auto context = static_cast<CT*>(_p);
                               context->first();
                               auto dg = context->second;
                               delete context;
                               dg->Decrement();
                           });
}
