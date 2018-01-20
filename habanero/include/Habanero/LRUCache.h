/* Copyright (c) 2018 Michael G. Kazakov
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

#include <utility>
#include <unordered_map>
#include <list>
#include <assert.h>

namespace hbn {

template <class _Key, class _Value, size_t _Capacity>
class LRUCache
{
public:
    LRUCache();
    LRUCache(const LRUCache&);
    LRUCache(LRUCache&&) = default;
    ~LRUCache() = default;
    
    bool empty() const noexcept;
    size_t size() const noexcept;
    size_t max_size() const noexcept;
    
    void clear();
    void insert( _Key _key, _Value _value );

    size_t count( const _Key &_key ) const noexcept;
    _Value &at( const _Key &_key );
    _Value &operator[]( const _Key &_key );
    
    LRUCache &operator=(const LRUCache&);
    LRUCache &operator=(LRUCache&&);
    
private:
    using KeyValue = std::pair<_Key, _Value>;
    using LRU = std::list<KeyValue>;
    using Map = std::unordered_map<_Key, typename LRU::iterator>;
    
    void evict();
    void make_front( typename LRU::iterator _it );
    
    Map m_Map;
    LRU m_LRU;
};

template <class _Key, class _Value, size_t _Capacity>
LRUCache<_Key, _Value, _Capacity>::LRUCache()
{
    static_assert( _Capacity > 0 );
}

template <class _Key, class _Value, size_t _Capacity>
LRUCache<_Key, _Value, _Capacity>::LRUCache(const LRUCache& _rhs)
{
    m_LRU = _rhs.m_LRU;
    for( auto i = std::begin(m_LRU), e = std::end(m_LRU); i != e; ++i )
        m_Map[ i->first ] = i;
}
    
template <class _Key, class _Value, size_t _Capacity>
size_t LRUCache<_Key, _Value, _Capacity>::size() const noexcept
{
    return m_LRU.size();
}
    
template <class _Key, class _Value, size_t _Capacity>
bool LRUCache<_Key, _Value, _Capacity>::empty() const noexcept
{
    return size() == 0;
}

template <class _Key, class _Value, size_t _Capacity>
size_t LRUCache<_Key, _Value, _Capacity>::max_size() const noexcept
{
    return _Capacity;
}

template <class _Key, class _Value, size_t _Capacity>
void LRUCache<_Key, _Value, _Capacity>::clear()
{
    m_Map.clear();
    m_LRU.clear();
}

template <class _Key, class _Value, size_t _Capacity>
void LRUCache<_Key, _Value, _Capacity>::insert(_Key _key, _Value _value)
{
    const auto it = m_Map.find( _key );
    if( it != std::end(m_Map) ) {
        it->second->second = std::move(_value);
        make_front(it->second);
    }
    else {
        if( size() == max_size() )
            evict();
        
        m_LRU.emplace_front( std::move(_key), std::move(_value) );
        m_Map[m_LRU.front().first] = std::begin(m_LRU);
    }
}

template <class _Key, class _Value, size_t _Capacity>
_Value &LRUCache<_Key, _Value, _Capacity>::at( const _Key &_key )
{
    const auto it = m_Map.find( _key );
    if( it != std::end(m_Map) ) {
        make_front(it->second);
        return it->second->second;
    }
    
    throw std::out_of_range("LRUCache::at(const _Key &_key): invalid key");
}

template <class _Key, class _Value, size_t _Capacity>
_Value &LRUCache<_Key, _Value, _Capacity>::operator[]( const _Key &_key )
{
    const auto it = m_Map.find( _key );
    if( it != std::end(m_Map) ) {
        make_front(it->second);
        return it->second->second;
    }
    
    if( size() == max_size() )
        evict();
    
    m_LRU.emplace_front( _key, _Value{} );
    m_Map[m_LRU.front().first] = std::begin(m_LRU);
    return m_LRU.front().second;
}

template <class _Key, class _Value, size_t _Capacity>
LRUCache<_Key, _Value, _Capacity> &LRUCache<_Key, _Value, _Capacity>::operator=(const LRUCache&_rhs)
{
    if( this == &_rhs )
        return *this;
    
    clear();
    m_LRU = _rhs.m_LRU;
    for( auto i = std::begin(m_LRU), e = std::end(m_LRU); i != e; ++i )
        m_Map[ i->first ] = i;

    return *this;
}

template <class _Key, class _Value, size_t _Capacity>
LRUCache<_Key, _Value, _Capacity> &LRUCache<_Key, _Value, _Capacity>::operator=(LRUCache &&_rhs)
{
    if( this == &_rhs )
        return *this;
    
    m_LRU = std::move(_rhs.m_LRU);
    m_Map = std::move(_rhs.m_Map);
    return *this;
}
    
template <class _Key, class _Value, size_t _Capacity>
void LRUCache<_Key, _Value, _Capacity>::make_front( typename LRU::iterator _it )
{
    m_LRU.splice( std::begin(m_LRU), m_LRU, _it );
}
    
template <class _Key, class _Value, size_t _Capacity>
void LRUCache<_Key, _Value, _Capacity>::evict()
{
    assert( size() == max_size() );
    m_Map.erase( m_LRU.back().first );
    m_LRU.pop_back();
}

template <class _Key, class _Value, size_t _Capacity>
size_t LRUCache<_Key, _Value, _Capacity>::count(const _Key &_key) const noexcept
{
    return m_Map.count(_key);
}
    
}
