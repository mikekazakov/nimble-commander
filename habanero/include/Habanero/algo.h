/* Copyright (c) 2015-2016 Michael G. Kazakov
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

#include <algorithm>
#include <memory>
#include <string>
#include <assert.h>
#include <stdio.h>

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
        std::equal( std::begin(_prefix),
                    std::end(_prefix),
                    std::begin(_string));
}

inline bool has_suffix( const std::string &_string, const std::string &_suffix )
{
    return _string.size() >= _suffix.size() &&
        std::equal( std::begin(_suffix),
                    std::end(_suffix),
                    std::begin(_string) + _string.size() - _suffix.size() );
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

template<class InputIt>
bool all_equal( InputIt _first, InputIt _last )
{
    if( _first == _last )
        return true;
    const auto &v = *(_first++);
    while( _first != _last )
        if( *(_first++) != v )
            return false;
    return true;
}

template<class InputIt, class UnaryPredicate>
bool all_equal( InputIt _first, InputIt _last, UnaryPredicate _p )
{
    if( _first == _last )
        return true;
    const auto &v = _p(*(_first++));
    while( _first != _last )
        if( _p(*(_first++)) != v )
            return false;
    return true;
}
