// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <atomic>
#include <queue>
#include <chrono>
#include <iostream>
#include <Base/mach_time.h>
#include <CoreFoundation/CoreFoundation.h>
#include <mutex>

template <class T>
struct AtomicHolder {
    AtomicHolder();
    AtomicHolder(T _value);
    bool wait_to_become(std::chrono::nanoseconds _timeout, const T &_new_value);
    bool wait_to_become_with_runloop(std::chrono::nanoseconds _timeout,
                                     std::chrono::nanoseconds _slice,
                                     const T &_new_value,
                                     bool _dump_on_fail = false);
    void store(const T &_new_value);
    T value;

private:
    std::condition_variable condvar;
    std::mutex mutex;
};

template <class T>
struct QueuedAtomicHolder {
    QueuedAtomicHolder();
    QueuedAtomicHolder(T _value);
    bool wait_to_become(std::chrono::nanoseconds _timeout, const T &_new_value);
    bool wait_to_become_with_runloop(std::chrono::nanoseconds _timeout,
                                     std::chrono::nanoseconds _slice,
                                     const T &_new_value,
                                     bool _dump_on_fail = false);
    void store(const T &_new_value);
    T load() const;
    void strict(bool _strict);

private:
    T m_Value;
    std::queue<T> m_Queue;
    std::condition_variable m_CondVar;
    mutable std::mutex m_Mutex;
    bool m_Strict = true;
};

template <class T>
AtomicHolder<T>::AtomicHolder() : value()
{
}

template <class T>
AtomicHolder<T>::AtomicHolder(T _value) : value(_value)
{
}

template <class T>
bool AtomicHolder<T>::wait_to_become(std::chrono::nanoseconds _timeout, const T &_new_value)
{
    std::unique_lock<std::mutex> lock(mutex);
    const auto pred = [&_new_value, this] { return value == _new_value; };
    return condvar.wait_for(lock, _timeout, pred);
}

template <class T>
bool AtomicHolder<T>::wait_to_become_with_runloop(std::chrono::nanoseconds _timeout,
                                                  std::chrono::nanoseconds _slice,
                                                  const T &_new_value,
                                                  bool _dump_on_fail)
{
    const auto deadline = nc::base::machtime() + _timeout;
    do {
        {
            std::unique_lock<std::mutex> lock(mutex);
            const auto pred = [&_new_value, this] { return value == _new_value; };
            if( condvar.wait_for(lock, _slice, pred) )
                return true;
        }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, std::chrono::duration<double>(_slice).count(), false);
    } while( deadline > nc::base::machtime() );
    if( _dump_on_fail ) {
        auto lg = std::lock_guard{mutex};
        std::cerr << value << std::endl;
    }
    return false;
}

template <class T>
void AtomicHolder<T>::store(const T &_new_value)
{
    {
        std::lock_guard<std::mutex> lock(mutex);
        value = _new_value;
    }
    condvar.notify_all();
}
template <class T>
QueuedAtomicHolder<T>::QueuedAtomicHolder() : m_Value()
{
}

template <class T>
QueuedAtomicHolder<T>::QueuedAtomicHolder(T _value) : m_Value(_value)
{
}

template <class T>
bool QueuedAtomicHolder<T>::wait_to_become(std::chrono::nanoseconds _timeout, const T &_new_value)
{
    std::unique_lock<std::mutex> lock(m_Mutex);
    const auto pred = [&_new_value, this] {
        if( m_Strict == false ) {
            while( !m_Queue.empty() && m_Queue.front() != _new_value )
                m_Queue.pop();
        }
        if( !m_Queue.empty() && m_Queue.front() == _new_value ) {
            m_Value = m_Queue.front();
            m_Queue.pop();
            return true;
        }
        return false;
    };
    return m_CondVar.wait_for(lock, _timeout, pred);
}

template <class T>
bool QueuedAtomicHolder<T>::wait_to_become_with_runloop(std::chrono::nanoseconds _timeout,
                                                        std::chrono::nanoseconds _slice,
                                                        const T &_new_value,
                                                        bool _dump_on_fail)
{
    const auto deadline = nc::base::machtime() + _timeout;
    do {
        if( wait_to_become(_slice, _new_value) )
            return true;
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, std::chrono::duration<double>(_slice).count(), false);
    } while( deadline > nc::base::machtime() );

    if( _dump_on_fail ) {
        auto lg = std::lock_guard{m_Mutex};
        std::cerr << m_Value << std::endl;
    }
    return false;
}

template <class T>
void QueuedAtomicHolder<T>::store(const T &_new_value)
{
    {
        std::lock_guard<std::mutex> lock(m_Mutex);
        m_Queue.push(_new_value);
    }
    m_CondVar.notify_all();
}

template <class T>
T QueuedAtomicHolder<T>::load() const
{
    std::lock_guard<std::mutex> lock(m_Mutex);
    return m_Value;
}

template <class T>
void QueuedAtomicHolder<T>::strict(bool _strict)
{
    m_Strict = _strict;
}
