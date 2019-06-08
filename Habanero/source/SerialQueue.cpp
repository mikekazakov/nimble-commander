// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/SerialQueue.h>

using namespace std;

SerialQueue::SerialQueue(const char *_label):
    m_Queue( dispatch_queue_create(_label, DISPATCH_QUEUE_SERIAL) )
{
}

SerialQueue::~SerialQueue()
{
    Stop();
    Wait();
}

void SerialQueue::SetOnDry( function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb =
        std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CallbackLock) {
        m_OnDry = cb;
    }
}

void SerialQueue::SetOnWet( function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb =
        std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CallbackLock) {
        m_OnWet = cb;
    }
}

void SerialQueue::SetOnChange( function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb =
        std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CallbackLock) {
        m_OnChange = cb;
    }
}

void SerialQueue::Stop()
{
    if(m_Length > 0)
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
    
    dispatch_sync_f( m_Queue, nullptr, [](void*){} );
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
    LOCK_GUARD(m_CallbackLock) {
        cb = m_OnDry;
    }
    if( cb && *cb )
        (*cb)();
}

void SerialQueue::FireWet() const
{
    std::shared_ptr<std::function<void()>> cb;
    LOCK_GUARD(m_CallbackLock) {
        cb = m_OnWet;
    }
    if( cb && *cb )
        (*cb)();
}

void SerialQueue::FireChanged() const
{
    std::shared_ptr<std::function<void()>> cb;
    LOCK_GUARD(m_CallbackLock) {
        cb = m_OnChange;
    }
    if( cb && *cb )
        (*cb)();
}
