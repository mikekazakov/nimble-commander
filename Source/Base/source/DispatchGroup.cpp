// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/DispatchGroup.h>

namespace nc::base {

DispatchGroup::DispatchGroup(Priority _priority)
    : m_Queue(dispatch_get_global_queue(_priority, 0)), m_Group(dispatch_group_create())
{
    if( !m_Queue || !m_Group )
        throw std::runtime_error("DispatchGroup::DispatchGroup(): can't create libdispatch objects");
}

DispatchGroup::~DispatchGroup()
{
    Wait();
    dispatch_release(m_Group);
}

void DispatchGroup::Wait() const noexcept
{
    dispatch_group_wait(m_Group, DISPATCH_TIME_FOREVER);
}

int DispatchGroup::Count() const noexcept
{
    return m_Count;
}

void DispatchGroup::SetOnDry(std::function<void()> _cb)
{
    const std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>(std::move(_cb));
    const auto lock = std::lock_guard{m_CallbackLock};
    m_OnDry = cb;
}

void DispatchGroup::SetOnWet(std::function<void()> _cb)
{
    const std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>(std::move(_cb));
    const auto lock = std::lock_guard{m_CallbackLock};
    m_OnWet = cb;
}

void DispatchGroup::SetOnChange(std::function<void()> _cb)
{
    const std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>(std::move(_cb));
    const auto lock = std::lock_guard{m_CallbackLock};
    m_OnChange = cb;
}

void DispatchGroup::Increment() const
{
    if( ++m_Count == 1 )
        FireWet();
    FireChange();
}

void DispatchGroup::Decrement() const
{
    if( --m_Count == 0 )
        FireDry();
    FireChange();
}

void DispatchGroup::FireDry() const
{
    std::shared_ptr<std::function<void()>> cb;
    {
        const auto lock = std::lock_guard{m_CallbackLock};
        cb = m_OnDry;
    }
    if( cb && *cb )
        (*cb)();
}

void DispatchGroup::FireWet() const
{
    std::shared_ptr<std::function<void()>> cb;
    {
        const auto lock = std::lock_guard{m_CallbackLock};
        cb = m_OnWet;
    }
    if( cb && *cb )
        (*cb)();
}

void DispatchGroup::FireChange() const
{
    std::shared_ptr<std::function<void()>> cb;
    {
        const auto lock = std::lock_guard{m_CallbackLock};
        cb = m_OnChange;
    }
    if( cb && *cb )
        (*cb)();
}

bool DispatchGroup::Empty() const noexcept
{
    return Count() == 0;
}

} // namespace nc::base
