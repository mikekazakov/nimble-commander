/* Copyright (c) 2017 Michael Kazakov <mike.kazakov@gmail.com>
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

#include <stdexcept>
#include <memory>
#include <new>
#include <vector>
#include <utility>
#include <functional>

class __fixed_eytzinger_map_base
{
public:
    // gratefully taken from llvm's libc++:
    template <class _Tp1, class _Tp2 = void>
    struct __is_transparent
    {
    private:
        struct __two {char __lx; char __lxx;};
        template <class _Up> static __two __test(...);
        template <class _Up> static char __test(typename _Up::is_transparent* = 0);
    public:
        static const bool value = sizeof(__test<_Tp1>(0)) == 1;
    };
    
    [[noreturn]] inline void __throw_at() const
    { throw std::out_of_range("fixed_eytzinger_map::at:  key not found"); }
    [[noreturn]] inline void __throw_sb() const
    { throw std::out_of_range("fixed_eytzinger_map::operator[]:  key not found"); }
    
};

template <typename _Key, typename _Value, class _Compare = std::less<_Key> >
class fixed_eytzinger_map : private _Compare, __fixed_eytzinger_map_base
{
    struct pair_ptr_wrap;
    struct const_pair_ptr_wrap;
    struct proxy_iterator;
    struct const_proxy_iterator;
public:
    typedef size_t                                  size_type;
    typedef std::pair<_Key,_Value>                  value_type;
    typedef _Key                                    key_type;
    typedef _Value                                  mapped_type;
    typedef _Compare                                key_compare;
    typedef proxy_iterator                          iterator;
    typedef const_proxy_iterator                    const_iterator;
    typedef std::pair<iterator,iterator>            range_pair;
    typedef std::pair<const_iterator,const_iterator>const_range_pair;
    
    static_assert( std::is_nothrow_move_constructible<key_type>::value,
        "key_type must be nothrow move constructible" );
    static_assert( std::is_nothrow_move_constructible<mapped_type>::value,
        "mapped_type must be nothrow move constructible" );    
    
    // Construction
    fixed_eytzinger_map();
    explicit fixed_eytzinger_map( const _Compare& comp );
    fixed_eytzinger_map( const fixed_eytzinger_map& _other );
    fixed_eytzinger_map( fixed_eytzinger_map&& other );
    fixed_eytzinger_map(std::initializer_list<value_type> l,
                        const _Compare& comp = _Compare() );
    template<typename _InputIterator>
    fixed_eytzinger_map(_InputIterator begin,
                        _InputIterator end,
                        const _Compare& comp = _Compare() );


    // Destruction
    ~fixed_eytzinger_map();


    // Element access
    mapped_type& at( const key_type& key );
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    mapped_type&>::type at( const _K2& key );
    
    const mapped_type& at( const key_type& key ) const;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    const mapped_type&>::type at( const _K2& key ) const;

    mapped_type& operator[]( const key_type& key );
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    mapped_type&>::type operator[]( const _K2& key );
    
    const mapped_type& operator[]( const key_type& key ) const;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    const mapped_type&>::type operator[]( const _K2& key ) const;
    
    
    // Iterators
    iterator       begin()     noexcept;
    iterator       end()       noexcept;
    const_iterator begin()     const noexcept;
    const_iterator end()       const noexcept;
    const_iterator cbegin()    const noexcept;
    const_iterator cend()      const noexcept;
    
    
    // Modifiers
    void clear() noexcept;
    void swap( fixed_eytzinger_map& other ) noexcept;
    
    
    // Capacity
    bool empty() const noexcept;
    size_type size() const noexcept;
    size_type max_size() const noexcept;
    
    
    // Lookup
    size_type count( const key_type& key ) const noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    size_type>::type count( const _K2& key ) const noexcept;

    iterator find( const key_type& key ) noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    iterator>::type find(const _K2& key) noexcept;
    
    const_iterator find( const key_type& key ) const noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    const_iterator>::type find(const _K2& key) const noexcept;
    
    range_pair equal_range( const key_type& key ) noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    range_pair>::type equal_range(const _K2& key) noexcept;

    const_range_pair equal_range( const key_type& key ) const noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    const_range_pair>::type equal_range(const _K2& key) const noexcept;

    iterator lower_bound( const key_type& key ) noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    iterator>::type lower_bound(const _K2& key) noexcept;
    
    const_iterator lower_bound( const key_type& key ) const noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    const_iterator>::type lower_bound(const _K2& key) const noexcept;
    
    iterator upper_bound( const key_type& key ) noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    iterator>::type upper_bound(const _K2& key) noexcept;
    
    const_iterator upper_bound( const key_type& key ) const noexcept;
    template <typename _K2> typename std::enable_if<__is_transparent<_Compare, _K2>::value,
    const_iterator>::type upper_bound(const _K2& key) const noexcept;
    
    
    // Assignment
    fixed_eytzinger_map& operator=( const fixed_eytzinger_map& other );
    fixed_eytzinger_map& operator=( fixed_eytzinger_map&& other ) noexcept;
    fixed_eytzinger_map& operator=( std::initializer_list<value_type> l );
    template<typename _InputIterator>
    void assign( _InputIterator begin, _InputIterator end );

    
private:
    void __alloc_init( size_t _count );
    void __deallocate() noexcept;
    void __construct_at( size_t _p, _Key &&_k, _Value &&_v ) noexcept;
    void __destroy_at( size_t _p ) noexcept;
    void __destroy_all() noexcept;
    bool __comp(const _Key& _v1, const _Key &_v2) const noexcept;
    template <class _K1, class _K2>
    bool __comp2(const _K1& _v1, const _K2 &_v2) const noexcept;
    value_type *__init_fill( size_t _base, value_type *_first);
    size_type    __m_count;
    key_type    *__m_keys;
    mapped_type *__m_values;
};

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>::fixed_eytzinger_map( ) :
 fixed_eytzinger_map( _Compare() )
{
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>::fixed_eytzinger_map( const _Compare& _comp ) :
    _Compare(_comp),
    __m_count(0),
    __m_keys(nullptr),
    __m_values(nullptr)
{
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>::
fixed_eytzinger_map( fixed_eytzinger_map&& _other ) :
    _Compare( _other ),
    __m_count( _other.__m_count ),
    __m_keys( _other.__m_keys ),
    __m_values( _other.__m_values )
{
    _other.__m_count = 0;
    _other.__m_keys = nullptr;
    _other.__m_values = nullptr;
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>::
fixed_eytzinger_map( const fixed_eytzinger_map& _other )
{
    __alloc_init( _other.__m_count );
    
    _Key *last_key = __m_keys;
    _Value *last_value = __m_values;
    try {
        for( size_type n = 0; n < __m_count; ++n, ++last_key )
            ::new((void*)(__m_keys+n)) _Key( _other.__m_keys[n] );
        for( size_type n = 0; n < __m_count; ++n, ++last_value )
            ::new((void*)(__m_values+n)) _Value( _other.__m_values[n] );
    }
    catch( ... ) {
        for( _Key *it = __m_keys; it < last_key; ++it )
            it->~_Key();
        for( _Value *it = __m_values; it < last_value; ++it )
            it->~_Value();
        __deallocate();
        std::rethrow_exception( std::current_exception() );
    }
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>::
fixed_eytzinger_map(std::initializer_list<value_type> _l,
                    const _Compare& _comp):
    _Compare(_comp),
    __m_count(0),
    __m_keys(nullptr),
    __m_values(nullptr)
{
    std::vector< std::pair<_Key,_Value> > t{ std::begin(_l), std::end(_l) };
    std::sort(t.begin(), t.end(), [](auto &_v1, auto &_v2) {
        return _v1.first < _v2.first;
    });
    t.erase( std::unique( t.begin(), t.end(), [](const auto &_v1, const auto &_v2){
        return _v1.first == _v2.first;
    }), t.end());
    
    __alloc_init( t.size() );
    __init_fill( 0, t.data() );
}

template <typename _Key, typename _Value, typename _Compare>
template<typename _InputIterator>
fixed_eytzinger_map<_Key, _Value, _Compare>::fixed_eytzinger_map(_InputIterator _begin,
                                                                 _InputIterator _end,
                                                                 const _Compare& _comp ):
    _Compare(_comp),
    __m_count(0),
    __m_keys(nullptr),
    __m_values(nullptr)
{
    static_assert( std::is_constructible<value_type,
                        typename std::iterator_traits<_InputIterator>::reference>::
                        value,
                    "incompatible iterator type");
    std::vector< std::pair<_Key,_Value> > t{ _begin, _end };
    std::sort(std::begin(t), std::end(t), [](auto &_v1, auto &_v2) {
        return _v1.first < _v2.first;
    });
    t.erase( std::unique( t.begin(), t.end(), [](const auto &_v1, const auto &_v2){
        return _v1.first == _v2.first;
    }), t.end());

    __alloc_init( t.size() );
    __init_fill( 0, t.data() );
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>::
~fixed_eytzinger_map()
{
    __destroy_all();
    __deallocate();
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::__deallocate() noexcept
{
    if( __m_keys ) {
        ::operator delete( __m_keys );
        __m_keys = nullptr;
    }
    if( __m_values ) {
        ::operator delete( __m_values );
        __m_values = nullptr;
    }
    __m_count = 0;
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::__destroy_at( size_t _p ) noexcept
{
    (__m_keys+_p)->~_Key();
    (__m_values+_p)->~_Value();
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::__destroy_all() noexcept
{
    for( _Key *_first = __m_keys, *_last = __m_keys + __m_count; _first != _last; _first++ )
        _first->~_Key();
    for( _Value *_first = __m_values, *_last = __m_values + __m_count; _first != _last; _first++ )
        _first->~_Value();
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::__alloc_init( size_t _count )
{
    __m_count = _count;
    try {
        __m_keys = static_cast<_Key*>( ::operator new(_count * sizeof(_Key)) );
        __m_values = static_cast<_Value*>( ::operator new(_count * sizeof(_Value)) );
    } catch( ... ) {
       __deallocate();
        std::rethrow_exception( std::current_exception() );
    }
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::
__construct_at( size_t _p, _Key &&_k, _Value &&_v ) noexcept
{
    ::new((void*)(__m_keys+_p)) _Key( std::move(_k) );
    ::new((void*)(__m_values+_p)) _Value( std::move(_v) );
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::value_type *
fixed_eytzinger_map<_Key, _Value, _Compare>::
__init_fill( size_t _base, value_type *_first )
{
    if( _base >= __m_count )
        return _first;

	_first = __init_fill( 2 * _base + 1, _first ); // left branch
    
    __construct_at( _base, std::move(_first->first), std::move(_first->second) ); // leaf
    ++_first;

	_first = __init_fill( 2 * _base + 2, _first ); // right branch

	return _first;
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::
clear() noexcept
{
    __destroy_all();
    __deallocate();
}

template <typename _Key, typename _Value, typename _Compare>
void fixed_eytzinger_map<_Key, _Value, _Compare>::
swap( fixed_eytzinger_map& other ) noexcept
{
    std::swap(__m_count, other.__m_count);
    std::swap(__m_keys, other.__m_keys);
    std::swap(__m_values, other.__m_values);
    std::swap((_Compare&)*this, (_Compare&)other);
}

template <typename _Key, typename _Value, typename _Compare>
bool fixed_eytzinger_map<_Key, _Value, _Compare>::
__comp(const _Key& _v1, const _Key &_v2) const noexcept
{
    return _Compare::operator()(_v1, _v2);
}

template <typename _Key, typename _Value, typename _Compare>
template <class _K1, class _K2>
bool fixed_eytzinger_map<_Key, _Value, _Compare>::
__comp2(const _K1& _v1, const _K2 &_v2) const noexcept
{
    return _Compare::operator()(_v1, _v2);
}

template <typename _Key, typename _Value, typename _Compare>
bool fixed_eytzinger_map<_Key,_Value, _Compare>::empty() const noexcept
{
    return __m_count == 0;
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::size_type
fixed_eytzinger_map<_Key, _Value, _Compare>::size() const noexcept
{
    return __m_count;
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::size_type
fixed_eytzinger_map<_Key, _Value, _Compare>::max_size() const noexcept
{
    return std::numeric_limits<size_type>::max() / 4;
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::begin() noexcept
{
    return iterator{ __m_keys, __m_values };
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::begin() const noexcept
{
    return const_iterator{ __m_keys, __m_values };
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::cbegin() const noexcept
{
    return begin();
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::end() noexcept
{
    return iterator{ __m_keys + __m_count, __m_values + __m_count };
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::end() const noexcept
{
    return const_iterator{ __m_keys + __m_count, __m_values + __m_count };
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::cend() const noexcept
{
    return end();
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::lower_bound(const _Key& _key) const noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp(__m_keys[j], _key) ){
            j = 2 * j + 2; // right branch
        }
        else {
            i = j;
            j = 2 * j + 1; // left branch
        }
    }
    return const_iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::lower_bound(const _K2& _key) const noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp2(__m_keys[j], _key) ){
            j = 2 * j + 2; // right branch
        }
        else {
            i = j;
            j = 2 * j + 1; // left branch
        }
    }
    return const_iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::lower_bound(const _Key& _key) noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp(__m_keys[j], _key) ){
            j = 2 * j + 2; // right branch
        }
        else {
            i = j;
            j = 2 * j + 1; // left branch
        }
    }
    return iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::lower_bound(const _K2& _key) noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp2(__m_keys[j], _key) ){
            j = 2 * j + 2; // right branch
        }
        else {
            i = j;
            j = 2 * j + 1; // left branch
        }
    }
    return iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::upper_bound( const key_type& _key ) noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp(_key, __m_keys[j]) ){
            i = j;
            j = 2 * j + 1; // left branch
        }
        else {
            j = 2 * j + 2; // right branch
        }
    }
    return iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::upper_bound( const _K2& _key ) noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp2(_key, __m_keys[j]) ){
            i = j;
            j = 2 * j + 1; // left branch
        }
        else {
            j = 2 * j + 2; // right branch
        }
    }
    return iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::upper_bound( const key_type& _key ) const noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp(_key, __m_keys[j]) ){
            i = j;
            j = 2 * j + 1; // left branch
        }
        else {
            j = 2 * j + 2; // right branch
        }
    }
    return const_iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::upper_bound( const _K2& _key ) const noexcept
{
    size_type i = __m_count, j = 0;
    while( j < __m_count ) {
        if( __comp2(_key, __m_keys[j]) ){
            i = j;
            j = 2 * j + 1; // left branch
        }
        else {
            j = 2 * j + 2; // right branch
        }
    }
    return const_iterator{__m_keys + i, __m_values + i};
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::find( const _Key& _key ) const noexcept
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return __p;
    return end();
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::find( const _K2& _key ) const noexcept
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return __p;
    return end();
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
fixed_eytzinger_map<_Key, _Value, _Compare>::find( const _Key& _key ) noexcept
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return __p;
    return end();
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::find( const _K2& _key ) noexcept
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return __p;
    return end();
}

template <typename _Key, typename _Value, typename _Compare>
std::pair<typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator,
          typename fixed_eytzinger_map<_Key, _Value, _Compare>::iterator>
fixed_eytzinger_map<_Key, _Value, _Compare>::equal_range( const _Key& _key ) noexcept
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return {__p, std::next(__p, 1)};
    return {end(), end()};
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::range_pair
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::equal_range( const _K2& _key ) noexcept
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return {__p, std::next(__p, 1)};
    return {end(), end()};
}

template <typename _Key, typename _Value, typename _Compare>
std::pair<typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator,
          typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_iterator>
fixed_eytzinger_map<_Key, _Value, _Compare>::equal_range( const _Key& _key ) const noexcept
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return {__p, std::next(__p, 1)};
    return {end(), end()};
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_range_pair
>::type
fixed_eytzinger_map<_Key, _Value, _Compare>::equal_range( const _K2& _key ) const noexcept
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return {__p, std::next(__p, 1)};
    return {end(), end()};
}

template <typename _Key, typename _Value, typename _Compare>
typename fixed_eytzinger_map<_Key, _Value, _Compare>::size_type
fixed_eytzinger_map<_Key, _Value, _Compare>::count( const key_type& _key ) const noexcept
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return 1;
    return 0;
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    typename fixed_eytzinger_map<_Key, _Value, _Compare>::size_type
>::type fixed_eytzinger_map<_Key, _Value, _Compare>::count( const _K2& _key ) const noexcept
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return 1;
    return 0;
}

template <typename _Key, typename _Value, typename _Compare>
_Value &fixed_eytzinger_map<_Key, _Value, _Compare>::
at( const key_type &_key )
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return *__p.v;
    __throw_at();
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    _Value&>
::type fixed_eytzinger_map<_Key, _Value, _Compare>::at( const _K2 &_key )
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return *__p.v;
    __throw_at();
}

template <typename _Key, typename _Value, typename _Compare>
const _Value &fixed_eytzinger_map<_Key, _Value, _Compare>::
at( const key_type &_key ) const
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return *__p.v;
    __throw_at();
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    const _Value&>
::type fixed_eytzinger_map<_Key, _Value, _Compare>::at( const _K2 &_key ) const
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return *__p.v;
    __throw_at();
}

template <typename _Key, typename _Value, typename _Compare>
_Value& fixed_eytzinger_map<_Key, _Value, _Compare>::
operator[]( const key_type& _key )
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return *__p.v;
    __throw_sb();
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    _Value&>
::type fixed_eytzinger_map<_Key, _Value, _Compare>::operator[]( const _K2 &_key )
{
    iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return *__p.v;
    __throw_sb();
}

template <typename _Key, typename _Value, typename _Compare>
const _Value& fixed_eytzinger_map<_Key, _Value, _Compare>::
operator[]( const key_type& _key ) const
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp(_key, *__p.k) )
        return *__p.v;
    __throw_sb();
}

template <typename _Key, typename _Value, typename _Compare>
template <typename _K2>
typename std::enable_if<
    __fixed_eytzinger_map_base::__is_transparent<_Compare, _K2>::value,
    const _Value&>
::type fixed_eytzinger_map<_Key, _Value, _Compare>::operator[]( const _K2 &_key ) const
{
    const_iterator __p = lower_bound(_key);
    if( __p != end() && !__comp2(_key, *__p.k) )
        return *__p.v;
    __throw_sb();
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>&
fixed_eytzinger_map<_Key, _Value, _Compare>::
operator=( fixed_eytzinger_map&& other ) noexcept
{
    clear();
    swap(other);
    return *this;
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>&
fixed_eytzinger_map<_Key, _Value, _Compare>::
operator=( const fixed_eytzinger_map& other )
{
    fixed_eytzinger_map __tmp {other};
    swap(__tmp);
    return *this;
}

template <typename _Key, typename _Value, typename _Compare>
fixed_eytzinger_map<_Key, _Value, _Compare>&
fixed_eytzinger_map<_Key, _Value, _Compare>::
operator=( std::initializer_list<value_type> l )
{
    fixed_eytzinger_map __tmp {l};
    swap(__tmp);
    return *this;
}

template <typename _Key, typename _Value, typename _Compare>
template<typename _InputIterator>
void fixed_eytzinger_map<_Key, _Value, _Compare>::
assign(_InputIterator _begin, _InputIterator _end)
{
    static_assert( std::is_constructible<value_type,
                        typename std::iterator_traits<_InputIterator>::reference>::
                        value,
                    "incompatible iterator type");
    fixed_eytzinger_map __tmp {_begin, _end};
    swap(__tmp);
}

template <typename _Key, typename _Value, typename _Compare>
struct fixed_eytzinger_map<_Key, _Value, _Compare>::pair_ptr_wrap :
    std::pair<const _Key&, _Value&>
{
    pair_ptr_wrap(const _Key *_k, _Value *_v) noexcept :
        std::pair<const _Key&, _Value&>(*_k, *_v) {}
    
    const std::pair<const _Key&, _Value&>* operator->() const noexcept
        { return this; }
};

template <typename _Key, typename _Value, typename _Compare>
struct fixed_eytzinger_map<_Key, _Value, _Compare>::const_pair_ptr_wrap :
    std::pair<const _Key&, const _Value&>
{
    const_pair_ptr_wrap(const _Key *_k, const _Value *_v) noexcept :
        std::pair<const _Key&, const _Value&>(*_k, *_v) {}
    
    const std::pair<const _Key&, const _Value&>* operator->() const noexcept
        { return this; }
};

template <typename _Key, typename _Value, typename _Compare>
struct fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator
{
    typedef std::random_access_iterator_tag         iterator_category;
    typedef ssize_t                                 difference_type;
    typedef std::pair<_Key, _Value>                 value_type;
    typedef pair_ptr_wrap                           pointer;
    typedef std::pair<const _Key&, _Value&>         reference;

    proxy_iterator() noexcept : k(nullptr), v(nullptr)
        { }
    proxy_iterator( const _Key *_k, _Value *_v ) noexcept : k(_k), v(_v)
        { }
    reference operator *() const noexcept
        { return reference{*k, *v}; }
    pointer operator->() const noexcept
        { return pointer{ k, v }; }
    reference operator[](difference_type _n) const noexcept
        { return *(*this + _n); }
    proxy_iterator &operator++() noexcept
        { ++k; ++v; return *this; }
    proxy_iterator operator++(int) noexcept
        { proxy_iterator __tmp = *this; ++(*this); return __tmp; }
    proxy_iterator &operator--() noexcept
        { --k; --v; return *this; }
    proxy_iterator operator--(int) noexcept
        { proxy_iterator __tmp = *this; --(*this); return __tmp; }
    proxy_iterator &operator+=(difference_type _d) noexcept
        { k += _d; v += _d; return *this; }
    proxy_iterator &operator-=(difference_type _d) noexcept
        { k -= _d; v -= _d; return *this; }
    proxy_iterator operator -(difference_type _d) noexcept
        { proxy_iterator __tmp = *this; return __tmp -= _d; }
    difference_type operator-(const proxy_iterator &_rhs) const noexcept
        { return k - _rhs.k; }
    bool operator ==(const proxy_iterator &_rhs) const noexcept
        { return k == _rhs.k; }
    bool operator !=(const proxy_iterator &_rhs) const noexcept
        { return k != _rhs.k; }
    bool operator  <(const proxy_iterator &_rhs) const noexcept
        { return k < _rhs.k; }
    bool operator  >(const proxy_iterator &_rhs) const noexcept
        { return k > _rhs.k; }
    bool operator <=(const proxy_iterator &_rhs) const noexcept
        { return k <= _rhs.k; }
    bool operator >=(const proxy_iterator &_rhs) const noexcept
        { return k >= _rhs.k; }
private:
    const _Key *k;
    _Value *v;
    friend class fixed_eytzinger_map;
};

template <typename _Key, typename _Value, typename _Compare>
inline typename fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator
operator+(typename fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator::difference_type __n,
          typename fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator __x) noexcept
{
    __x += __n;
    return __x;
}

template <typename _Key, typename _Value, typename _Compare>
inline typename fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator
operator+(typename fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator __x,
          typename fixed_eytzinger_map<_Key, _Value, _Compare>::proxy_iterator::difference_type __n
          ) noexcept
{
    __x += __n;
    return __x;
}

template <typename _Key, typename _Value, typename _Compare>
struct fixed_eytzinger_map<_Key, _Value, _Compare>::const_proxy_iterator
{
    typedef std::random_access_iterator_tag         iterator_category;
    typedef ssize_t                                 difference_type;
    typedef std::pair<_Key, _Value>                 value_type;
    typedef const_pair_ptr_wrap                     pointer;
    typedef std::pair<const _Key&, const _Value&>   reference;

    const_proxy_iterator() noexcept : k(nullptr), v(nullptr)
        { }
    const_proxy_iterator( const _Key *_k, const _Value *_v ) noexcept : k(_k), v(_v)
        { }
    reference operator *() const noexcept
        { return reference{*k, *v}; }
    pointer operator->() const noexcept
        { return pointer{ k, v }; }
    reference operator[](difference_type _n) const noexcept
        { return *(*this + _n); }
    const_proxy_iterator &operator++() noexcept
        { ++k; ++v; return *this; }
    const_proxy_iterator operator++(int) noexcept
        { proxy_iterator __tmp = *this; ++(*this); return __tmp; }
    const_proxy_iterator &operator--() noexcept
        { --k; --v; return *this; }
    const_proxy_iterator operator--(int) noexcept
        { proxy_iterator __tmp = *this; --(*this); return __tmp; }
    const_proxy_iterator &operator+=(difference_type _d) noexcept
        { k += _d; v += _d; return *this; }
    const_proxy_iterator &operator-=(difference_type _d) noexcept
        { k -= _d; v -= _d; return *this; }
    const_proxy_iterator operator -(difference_type _d) noexcept
        { proxy_iterator __tmp = *this; return __tmp -= _d; }
    difference_type operator-(const const_proxy_iterator &_rhs) const noexcept
        { return k - _rhs.k; }
    bool operator ==(const const_proxy_iterator &_rhs) const noexcept
        { return k == _rhs.k; }
    bool operator !=(const const_proxy_iterator &_rhs) const noexcept
        { return k != _rhs.k; }
    bool operator  <(const const_proxy_iterator &_rhs) const noexcept
        { return k < _rhs.k; }
    bool operator  >(const const_proxy_iterator &_rhs) const noexcept
        { return k > _rhs.k; }
    bool operator <=(const const_proxy_iterator &_rhs) const noexcept
        { return k <= _rhs.k; }
    bool operator >=(const const_proxy_iterator &_rhs) const noexcept
        { return k >= _rhs.k; }
private:
    const _Key *k;
    const _Value *v;
    friend class fixed_eytzinger_map;
};

template <typename _Key, typename _Value, typename _Compare>
inline typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_proxy_iterator
operator+(typename fixed_eytzinger_map<_Key, _Value, _Compare>::
            const_proxy_iterator::difference_type __n,
          typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_proxy_iterator __x) noexcept
{
    __x += __n;
    return __x;
}

template <typename _Key, typename _Value, typename _Compare>
inline typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_proxy_iterator
operator+(typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_proxy_iterator __x,
          typename fixed_eytzinger_map<_Key, _Value, _Compare>::const_proxy_iterator::
            difference_type __n
          ) noexcept
{
    __x += __n;
    return __x;
}

template <typename _Key, typename _Value, typename _Compare>
inline bool
operator==(const fixed_eytzinger_map<_Key, _Value, _Compare>& __x,
           const fixed_eytzinger_map<_Key, _Value, _Compare>& __y)
{
    return __x.size() == __y.size() && std::equal(__x.begin(), __x.end(), __y.begin());
}

template <typename _Key, typename _Value, typename _Compare>
inline bool
operator!=(const fixed_eytzinger_map<_Key, _Value, _Compare>& __x,
           const fixed_eytzinger_map<_Key, _Value, _Compare>& __y)
{
    return !(__x == __y);
}

namespace std
{
template <typename _Key, typename _Value, typename _Compare>
inline void swap(fixed_eytzinger_map<_Key, _Value, _Compare>& __x,
                 fixed_eytzinger_map<_Key, _Value, _Compare>& __y )
{
    __y.swap( __x );
}
}
