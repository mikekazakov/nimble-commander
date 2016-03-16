#include <Habanero/algo.h>
#include <Habanero/mach_time.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/KVO.h>

void KeyValueObservation::NotifyWillChange(short _key)
{
    auto time = machtime();
    for( size_t index = 0, e = m_Keys.size(); index != e; ++index )
        if( m_Keys[index] == _key ) {
            auto &o = m_Observers[index];
            
            if( o.fire_limit.count() != 0 && o.last_fired + o.fire_limit > time )
                    continue;
            
            if( o.before ) {
                if( o.fire_async )
                    dispatch_to_main_queue( [handler=o.before]{ (*handler)(); } );
                else
                    (*o.before)();
            }
        }
}

void KeyValueObservation::NotifyDidChange(short _key)
{
    auto time = machtime();
    for( size_t index = 0, e = m_Keys.size(); index != e; ++index )
        if( m_Keys[index] == _key ) {
            auto &o = m_Observers[index];
            
            if( o.fire_limit.count() != 0 ) {
                if( o.last_fired + o.fire_limit > time )
                    continue;
                o.last_fired = time;
            }
            
            if( o.after ) {
                if( o.fire_async )
                    dispatch_to_main_queue( [handler=o.after]{ (*handler)(); } );
                else
                    (*o.after)();
            }
        }
}

void KeyValueObservation::RegisterObserver(short _key,
                                           std::function<void()> _before_change,
                                           std::function<void()> _after_change,
                                           bool _fire_async,
                                           std::chrono::nanoseconds _fire_limit)
{
    if( !_before_change && !_after_change )
        return; // nothing to call - no need to register
    
    Observation o;
    o.before = _before_change ? to_shared_ptr( std::move(_before_change) ) : nullptr;
    o.after  = _after_change ? to_shared_ptr( std::move(_after_change ) ) : nullptr;
    o.fire_async = _fire_async;
    o.last_fired = std::chrono::nanoseconds(0);
    o.fire_limit = _fire_limit;
    
    m_Observers.emplace_back( std::move(o) );
    m_Keys.emplace_back(_key);
}
