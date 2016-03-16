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
