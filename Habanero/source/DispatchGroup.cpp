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
#include <Habanero/DispatchGroup.h>

DispatchGroup::DispatchGroup(Priority _priority):
    m_Queue(dispatch_get_global_queue(_priority, 0)),
    m_Group(dispatch_group_create())
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

void DispatchGroup::SetOnDry( std::function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb =
        std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CallbackLock) {
        m_OnDry = cb;
    }
}

void DispatchGroup::SetOnWet( std::function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb =
        std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CallbackLock) {
        m_OnWet = cb;
    }
}

void DispatchGroup::SetOnChange( std::function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb =
        std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CallbackLock) {
        m_OnChange = cb;
    }
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
    LOCK_GUARD(m_CallbackLock) {
        cb = m_OnDry;
    }
    if( cb && *cb )
        (*cb)();
}

void DispatchGroup::FireWet() const
{
    std::shared_ptr<std::function<void()>> cb;
    LOCK_GUARD(m_CallbackLock) {
        cb = m_OnWet;
    }
    if( cb && *cb )
        (*cb)();
}

void DispatchGroup::FireChange() const
{
    std::shared_ptr<std::function<void()>> cb;
    LOCK_GUARD(m_CallbackLock) {
        cb = m_OnChange;
    }
    if( cb && *cb )
        (*cb)();
}

bool DispatchGroup::Empty() const noexcept
{
    return Count() == 0;
}
