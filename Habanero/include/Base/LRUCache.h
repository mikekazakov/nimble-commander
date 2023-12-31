// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <utility>
#include <unordered_map>
#include <list>
#include <assert.h>

namespace nc::base {

template <class _Key, class _Value, size_t _Capacity, class _Hash = std::hash<_Key>>
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

    /**
     * Returns 1 if there is a value associated with _key, or 0 otherwise.
     * Does not change LRU order.
     * O(1).
     */
    size_t count( const _Key &_key ) const noexcept;
    
    /**
     * Checks whether there is a value corresponding to _key. If there is - makes it the most
     * recent and returns a reference to the value. Otherwise, throws an exception.
     * O(1).
     */
    _Value &at( const _Key &_key );
    
    /**
     * Checks whether there is a value corresponding to _key. If there is - makes it the most
     * recent and returns a reference to the value. Otherwise, creates a (_key, Value{}) pair,
     * inserts it to the front and returns a references to the value.
     * May evict another value in the process if cache is already at max_size().
     * O(1).
     */
    _Value &operator[]( const _Key &_key );
    
    LRUCache &operator=(const LRUCache&);
    LRUCache &operator=(LRUCache&&);
    
private:
    using KeyValue = std::pair<_Key, _Value>;
    using LRU = std::list<KeyValue>;
    using Map = std::unordered_map<_Key, typename LRU::iterator, _Hash>;
    
    void evict();
    void make_front( typename LRU::iterator _it );
    
    Map m_Map;
    LRU m_LRU;
};

template <class _Key, class _Value, size_t _Capacity, class _Hash>
LRUCache<_Key, _Value, _Capacity, _Hash>::LRUCache()
{
    static_assert( _Capacity > 0 );
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
LRUCache<_Key, _Value, _Capacity, _Hash>::LRUCache(const LRUCache& _rhs)
{
    m_LRU = _rhs.m_LRU;
    for( auto i = std::begin(m_LRU), e = std::end(m_LRU); i != e; ++i )
        m_Map[ i->first ] = i;
}
    
template <class _Key, class _Value, size_t _Capacity, class _Hash>
size_t LRUCache<_Key, _Value, _Capacity, _Hash>::size() const noexcept
{
    return m_LRU.size();
}
    
template <class _Key, class _Value, size_t _Capacity, class _Hash>
bool LRUCache<_Key, _Value, _Capacity, _Hash>::empty() const noexcept
{
    return size() == 0;
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
size_t LRUCache<_Key, _Value, _Capacity, _Hash>::max_size() const noexcept
{
    return _Capacity;
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
void LRUCache<_Key, _Value, _Capacity, _Hash>::clear()
{
    m_Map.clear();
    m_LRU.clear();
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
void LRUCache<_Key, _Value, _Capacity, _Hash>::insert(_Key _key, _Value _value)
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
        auto front = std::begin(m_LRU);
        m_Map.emplace( std::make_pair(front->first, front) );
    }
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
_Value &LRUCache<_Key, _Value, _Capacity, _Hash>::at( const _Key &_key )
{
    const auto it = m_Map.find( _key );
    if( it != std::end(m_Map) ) {
        make_front(it->second);
        return it->second->second;
    }
    
    throw std::out_of_range("LRUCache::at(const _Key &_key): invalid key");
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
_Value &LRUCache<_Key, _Value, _Capacity, _Hash>::operator[]( const _Key &_key )
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

template <class _Key, class _Value, size_t _Capacity, class _Hash>
LRUCache<_Key, _Value, _Capacity, _Hash> &
LRUCache<_Key, _Value, _Capacity, _Hash>::operator=(const LRUCache&_rhs)
{
    if( this == &_rhs )
        return *this;
    
    clear();
    m_LRU = _rhs.m_LRU;
    for( auto i = std::begin(m_LRU), e = std::end(m_LRU); i != e; ++i )
        m_Map[ i->first ] = i;

    return *this;
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
LRUCache<_Key, _Value, _Capacity, _Hash> &
LRUCache<_Key, _Value, _Capacity, _Hash>::operator=(LRUCache &&_rhs)
{
    if( this == &_rhs )
        return *this;
    
    m_LRU = std::move(_rhs.m_LRU);
    m_Map = std::move(_rhs.m_Map);
    return *this;
}
    
template <class _Key, class _Value, size_t _Capacity, class _Hash>
void LRUCache<_Key, _Value, _Capacity, _Hash>::make_front( typename LRU::iterator _it )
{
    m_LRU.splice( std::begin(m_LRU), m_LRU, _it );
}
    
template <class _Key, class _Value, size_t _Capacity, class _Hash>
void LRUCache<_Key, _Value, _Capacity, _Hash>::evict()
{
    assert( size() == max_size() );
    m_Map.erase( m_LRU.back().first );
    m_LRU.pop_back();
}

template <class _Key, class _Value, size_t _Capacity, class _Hash>
size_t LRUCache<_Key, _Value, _Capacity, _Hash>::count(const _Key &_key) const noexcept
{
    return m_Map.count(_key);
}
    
}
