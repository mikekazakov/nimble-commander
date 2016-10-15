//
//  algo.h
//  Habanero
//
//  Created by Michael G. Kazakov on 11/09/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#pragma once

#include <algorithm>
#include <memory>
#include <string>
#include <assert.h>
#include <stdio.h>

/**
 * return max(lower, min(n, upper));
 */
template <typename T__>
inline T__ clip(const T__& n, const T__& lower, const T__& upper)
{
    return max(lower, min(n, upper));
}

template <typename T>
auto linear_generator( T _base, T _step )
{
    return [=,value = _base] () mutable {
        auto v = value;
        value += _step;
        return v;
    };
}

template <typename C, typename T>
size_t linear_find_or_insert( C &_c, const T &_v )
{
    auto b = std::begin(_c), e = std::end(_c);
    auto it = std::find( b,  e, _v );
    if( it != e )
        return std::distance(b, it);
    
    _c.emplace_back( _v );
    return _c.size() - 1;
}

template <typename C>
std::shared_ptr<C> to_shared_ptr( C &&_object )
{
    return std::make_shared<C>( std::move(_object) );
}

template <typename T>
auto at_scope_end( T _l )
{
    struct guard
    {
        guard( T &&_lock ):
            m_l(std::move(_lock))
        {
        }
        
        guard( guard&& ) = default;
        
        ~guard() noexcept
        {
            if( m_engaged )
                try {
                    m_l();
                }
                catch(...) {
                    fprintf(stderr, "exception thrown inside a at_scope_end() lambda!\n");
                }
        }
        
        bool engaded() const noexcept
        {
            return m_engaged;
        }
        
        void engage() noexcept
        {
            m_engaged = true;
        }
        
        void disengage() noexcept
        {
            m_engaged = false;
        }
        
    private:
        T m_l;
        bool m_engaged = true;
    };
    
    return guard( std::move(_l) );
}

inline bool has_prefix( const std::string &_string, const std::string &_prefix )
{
    return _string.size() >= _prefix.size() &&
        std::equal( begin(_prefix),
                    end(_prefix),
                    begin(_string));
}

class upward_flag
{
    bool _state = false;
public:
    inline operator bool() const noexcept { return _state; };
    inline void toggle() noexcept { _state = true; };
};

class downward_flag
{
    bool _state = true;
public:
    inline operator bool() const noexcept { return _state; };
    inline void toggle() noexcept { _state = false; };
};

// remove this after switching to C++17
template<class T, class Compare>
constexpr const T& clamp( const T& v, const T& lo, const T& hi, Compare comp )
{
    return assert( !comp(hi, lo) ),
    comp(v, lo) ? lo : comp(hi, v) ? hi : v;
}

template<class T>
constexpr const T& clamp( const T& v, const T& lo, const T& hi )
{
    return clamp( v, lo, hi, std::less<>() );
}
