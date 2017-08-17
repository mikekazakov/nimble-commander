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
    
    dispatch_sync_f( m_Queue, nullptr, [](void* _p){} );
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
