/* Copyright (c) 2015 Michael G. Kazakov
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

#include <functional>
#include <memory>
#include <vector>
#include <chrono>
#include "spinlock.h"

// currently KVO is NOT thread-safe and using it concurrently will mess things up!
class KeyValueObservation
{
public:
    void RegisterObserver(short _key,
                          std::function<void()> _before_change,
                          std::function<void()> _after_change,
                          bool _fire_async = true,
                          std::chrono::nanoseconds _fire_limit = std::chrono::nanoseconds(0)
                          );
    template <typename T>
    void RegisterObserver(T _key,
                          std::function<void()> _before_change,
                          std::function<void()> _after_change,
                          bool _fire_async = true,
                          std::chrono::nanoseconds _fire_limit = std::chrono::nanoseconds(0)
                          )
    { RegisterObserver((short)_key, move(_before_change), move(_after_change), _fire_async, _fire_limit); }
    
protected:
    void NotifyWillChange(short _key);
    template <typename T> void NotifyWillChange(T _key) { NotifyWillChange((short)_key); }
    
    void NotifyDidChange(short _key);
    template <typename T> void NotifyDidChange(T _key) { NotifyDidChange((short)_key); }
    
private:
    struct Observation
    {
        std::shared_ptr< std::function<void()> >    before;
        std::shared_ptr< std::function<void()> >    after;
        bool                                        fire_async;
        std::chrono::nanoseconds                    fire_limit;
        std::chrono::nanoseconds                    last_fired;
    };
    
    std::vector<Observation>    m_Observers;
    std::vector<short>          m_Keys;
};
