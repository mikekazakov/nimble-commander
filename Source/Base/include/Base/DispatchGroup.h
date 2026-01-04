// Copyright (C) 2014-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <memory>
#include <functional>
#include <atomic>
#include "dispatch_cpp.h"
#include "spinlock.h"

namespace nc::base {

class DispatchGroup
{
public:
    enum Priority : int16_t {
        High = DISPATCH_QUEUE_PRIORITY_HIGH,
        Default = DISPATCH_QUEUE_PRIORITY_DEFAULT,
        Low = DISPATCH_QUEUE_PRIORITY_LOW,
        Background = DISPATCH_QUEUE_PRIORITY_BACKGROUND
    };

    /**
     * Creates a dispatch group and gets a shared oncurrent queue.
     */
    DispatchGroup(Priority _priority = Default);

    DispatchGroup(const DispatchGroup &) = delete;

    /**
     * Will wait for completion before destruction.
     */
    ~DispatchGroup();

    void operator=(const DispatchGroup &) = delete;

    /**
     * Run _f in group on queue with prioriry specified at construction time.
     * This might be a lambda, or a function<void()> or anything else callable.
     */
    template <class T>
    void Run(T _f) const;

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
    void SetOnDry(std::function<void()> _cb);

    /**
     * Set a callback function which will be called when Count() becomes non-zero for first time.
     * Might be called from undefined background thread.
     * Reentrant.
     */
    void SetOnWet(std::function<void()> _cb);

    /**
     * Set a callback function which will be called every time Count() changes.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~DispatchGroup().
     * Reentrant.
     */
    void SetOnChange(std::function<void()> _cb);

private:
    void Increment() const;
    void Decrement() const;
    void FireDry() const;
    void FireWet() const;
    void FireChange() const;

    dispatch_queue_t m_Queue;
    dispatch_group_t m_Group;
    mutable std::atomic_int m_Count{0};
    mutable nc::spinlock m_CallbackLock;
    std::shared_ptr<std::function<void()>> m_OnDry;
    std::shared_ptr<std::function<void()>> m_OnWet;
    std::shared_ptr<std::function<void()>> m_OnChange;
};

template <class T>
void DispatchGroup::Run(T _f) const
{
    using CT = std::pair<T, const DispatchGroup *>;
    Increment();
    dispatch_group_async_f(m_Group, m_Queue, new CT(std::move(_f), this), [](void *_p) {
        auto context = static_cast<CT *>(_p);
        context->first();
        auto dg = context->second;
        delete context;
        dg->Decrement();
    });
}

} // namespace nc::base
