// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/SerialQueue.h>

namespace nc::base {

SerialQueue::SerialQueue(const char *_label) : m_Queue(dispatch_queue_create(_label, DISPATCH_QUEUE_SERIAL))
{
}

SerialQueue::~SerialQueue()
{
    Stop();
    Wait();
}

void SerialQueue::SetOnDry(std::function<void()> _on_dry)
{
    const std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>(std::move(_on_dry));
    const auto lock = std::lock_guard{m_CallbackLock};
    m_OnDry = cb;
}

void SerialQueue::SetOnWet(std::function<void()> _on_wet)
{
    const std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>(std::move(_on_wet));
    const auto lock = std::lock_guard{m_CallbackLock};
    m_OnWet = cb;
}

void SerialQueue::SetOnChange(std::function<void()> _on_change)
{
    const std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>(std::move(_on_change));
    const auto lock = std::lock_guard{m_CallbackLock};
    m_OnChange = cb;
}

void SerialQueue::Stop()
{
    if( m_Length > 0 )
        m_Stopped = true;
}

bool SerialQueue::IsStopped() const
{
    return m_Stopped;
}

void SerialQueue::Increment() const
{
    if( ++m_Length == 1 )
        FireWet();
    FireChanged();
}

void SerialQueue::Decrement() const
{
    if( --m_Length == 0 )
        FireDry();
    FireChanged();
}

void SerialQueue::Wait()
{
    if( Empty() )
        return;

    dispatch_sync_f(m_Queue, nullptr, [](void *) {});
}

int SerialQueue::Length() const noexcept
{
    return m_Length;
}

bool SerialQueue::Empty() const noexcept
{
    return m_Length == 0;
}

void SerialQueue::FireDry() const
{
    m_Stopped = false;

    std::shared_ptr<std::function<void()>> cb;
    {
        const auto lock = std::lock_guard{m_CallbackLock};
        cb = m_OnDry;
    }
    if( cb && *cb )
        (*cb)();
}

void SerialQueue::FireWet() const
{
    std::shared_ptr<std::function<void()>> cb;
    {
        const auto lock = std::lock_guard{m_CallbackLock};
        cb = m_OnWet;
    }
    if( cb && *cb )
        (*cb)();
}

void SerialQueue::FireChanged() const
{
    std::shared_ptr<std::function<void()>> cb;
    {
        const auto lock = std::lock_guard{m_CallbackLock};
        cb = m_OnChange;
    }
    if( cb && *cb )
        (*cb)();
}

} // namespace nc::base
