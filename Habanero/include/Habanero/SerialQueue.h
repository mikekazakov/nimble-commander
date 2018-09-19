/* Copyright (c) 2013-2016 Michael G. Kazakov
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

class SerialQueue
{
public:
    SerialQueue( const char *_label = nullptr );
    
    /**
     * Will invoke Stop() and Wait() inside.
     */
    ~SerialQueue();
    
     /**
     * Starts _f asynchronously in this queue.
     */
    template <class T>
    void Run( T _f ) const;
    
    /**
     * Raises IsStopped() flag so currently running tasks can caught it.
     * Will hold this flag more until queue became dry, then will automaticaly lower this flag.
     */
    void Stop();
    
    /**
     * Synchronously waits until queue became dry, if queue is not Empty().
     * Note that OnDry() will be called before Wait() will return.
     */
    void Wait();
    
    /**
     * Returns value of the stop flag.
     */
    bool IsStopped() const;
    
    /**
     * Returns count of block commited into queue, including currently running block, if any.
     * Zero returned length means that queue is dry.
     */
    int Length() const noexcept;
    
    /**
     * Actually returns Length() == 0. Just a syntax sugar.
     */
    bool Empty() const noexcept;
    
    /**
     * Sets handler to be called when queue becomes dry (no blocks are commited or running).
     * Stop flag will be lowered automatically anyway.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~SerialQueue().
     * Reentrant.
     */
    void SetOnDry( std::function<void()> _on_dry );
    
    /**
     * Sets handler to be called when queue becomes wet (when block is commited to run in it).
     * Might be called from undefined background thread.
     * Reentrant.
     */
    void SetOnWet( std::function<void()> _on_wet );
    
    /**
     * Sets handler to be called very time when queue length is changed.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~SerialQueue().
     * Reentrant.
     */
    void SetOnChange( std::function<void()> _on_change );
    
private:
    SerialQueue(const SerialQueue&) = delete;
    void operator=(const SerialQueue&) = delete;
    void Increment() const;
    void Decrement() const;
    void FireDry() const;
    void FireWet() const;
    void FireChanged() const;
    dispatch_queue_t            m_Queue;
    mutable std::atomic_int     m_Length = {0};
    mutable std::atomic_bool    m_Stopped = {false};
    mutable spinlock            m_CallbackLock;
    std::shared_ptr<std::function<void()>>  m_OnDry;
    std::shared_ptr<std::function<void()>>  m_OnWet;
    std::shared_ptr<std::function<void()>>  m_OnChange;
};

template <class T>
inline void SerialQueue::Run( T _f ) const
{
    using CT = std::pair<T, const SerialQueue*>;
    Increment();
    dispatch_async_f(m_Queue,
                     new CT( std::move(_f), this ),
                     [](void* _p) {
                         auto context = static_cast<CT*>(_p);
                         context->first();
                         auto dq = context->second;
                         delete context;
                         dq->Decrement();
                     });
}
