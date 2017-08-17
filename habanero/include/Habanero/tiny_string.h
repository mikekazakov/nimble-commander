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

#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <numeric>
#include <iterator>
#include <stdexcept>
#include <string>

// sizeof(tiny_string) == 8.
class tiny_string
{
    template <class _Tp> struct __is_input_iterator:
    public std::is_convertible< typename std::iterator_traits<_Tp>::iterator_category, std::input_iterator_tag > {};
    template <class _Tp> struct __is_forward_iterator:
    public std::is_convertible< typename std::iterator_traits<_Tp>::iterator_category, std::forward_iterator_tag > {};
public:
    typedef std::char_traits<char>                  traits_type;
    typedef traits_type::char_type                  value_type;
    typedef uint32_t                                size_type;
    typedef std::ptrdiff_t                          difference_type;
    typedef value_type&                             reference;
    typedef const value_type&                       const_reference;
    typedef value_type*                             pointer;
    typedef const value_type*                       const_pointer;
    typedef pointer                                 iterator;
    typedef const_pointer                           const_iterator;
    typedef std::reverse_iterator<iterator>         reverse_iterator;
    typedef std::reverse_iterator<const_iterator>   const_reverse_iterator;
    static const size_type                          npos = -1;
    
    //////////////////////////////////////////////////////////////////////////////
    // Construction/destruction
    ///////////////////////////
    tiny_string();
    tiny_string( size_type count, char ch );
    tiny_string( const tiny_string& other, size_type pos, size_type count = npos );
    tiny_string( const_pointer s, size_type count );
    tiny_string( const_pointer s );
    template< class Iterator >
    tiny_string( Iterator first, Iterator last);
    tiny_string( const tiny_string &s );
    tiny_string( tiny_string &&s ) noexcept;
    tiny_string( std::initializer_list<value_type> init );
    tiny_string( const std::string &s );
    ~tiny_string();
    
    //////////////////////////////////////////////////////////////////////////////
    // Assigning
    ////////////
    tiny_string&            assign( size_type count, value_type ch );
    tiny_string&            assign( const tiny_string& str );
    tiny_string&            assign( const tiny_string& str, size_type pos, size_type count = npos );
    tiny_string&            assign( tiny_string&& str ) noexcept;
    tiny_string&            assign( const_pointer s, size_type count );
    tiny_string&            assign( const_pointer s );
    template< class Iterator >
    tiny_string&            assign( Iterator first, Iterator last );
    tiny_string&            assign( std::initializer_list<value_type> ilist );
    tiny_string&            operator=( const tiny_string& str );
    tiny_string&            operator=( tiny_string&& str ) noexcept;
    tiny_string&            operator=( const_pointer s );
    tiny_string&            operator=( value_type ch );
    tiny_string&            operator=( std::initializer_list<value_type> ilist );
    
    //////////////////////////////////////////////////////////////////////////////
    // Element access
    /////////////////
    reference               at( size_type pos );
    const_reference         at( size_type pos ) const;
    reference               operator[]( size_type pos );
    const_reference         operator[]( size_type pos ) const;
    reference               front();
    const_reference         front()     const;
    reference               back();
    const_reference         back()      const;
    const_pointer           data()      const   noexcept;
    const_pointer           c_str()     const   noexcept;

    //////////////////////////////////////////////////////////////////////////////
    // Iterators
    ////////////
    iterator                begin()             noexcept;
    const_iterator          begin()     const   noexcept;
    const_iterator          cbegin()    const   noexcept;
    iterator                end()               noexcept;
    const_iterator          end()       const   noexcept;
    const_iterator          cend()      const   noexcept;
    reverse_iterator        rbegin()            noexcept;
    const_reverse_iterator  rbegin()    const   noexcept;
    const_reverse_iterator  crbegin()   const   noexcept;
    reverse_iterator        rend()              noexcept;
    const_reverse_iterator  rend()      const   noexcept;
    const_reverse_iterator  crend()     const   noexcept;

    //////////////////////////////////////////////////////////////////////////////
    // Capacity
    ///////////
    bool                    empty()     const   noexcept;
    size_type               size()      const   noexcept;
    size_type               length()    const   noexcept;
    size_type               max_size()  const   noexcept;
    void                    reserve( size_type new_cap = 0 );
    size_type               capacity()  const   noexcept;
    void                    shrink_to_fit();

    //////////////////////////////////////////////////////////////////////////////
    // Operations
    /////////////
    void                    clear()             noexcept;
    tiny_string&            insert( size_type index, size_type count, value_type ch );
    tiny_string&            insert( size_type index, const_pointer s );
    tiny_string&            insert( size_type index, const_pointer s, size_type count );
    tiny_string&            insert( size_type index, const tiny_string& str );
    tiny_string&            insert( size_type index, const tiny_string& str, size_type index_str, size_type count = npos );
    iterator                insert( const_iterator pos, value_type ch );
    iterator                insert( const_iterator pos, size_type count, value_type ch );
    template<class InputIterator>
    typename std::enable_if< __is_input_iterator<InputIterator>::value && !__is_forward_iterator<InputIterator>::value, iterator
    >::type                 insert( const_iterator pos, InputIterator first, InputIterator last );
    template<class ForwardIterator>
    typename std::enable_if< __is_forward_iterator<ForwardIterator>::value, iterator
    >::type                 insert( const_iterator pos, ForwardIterator first, ForwardIterator last );
    iterator                insert( const_iterator pos, std::initializer_list<value_type> ilist );
    tiny_string&            erase( size_type index = 0, size_type count = npos );
    iterator                erase( const_iterator pos );
    iterator                erase( const_iterator first, const_iterator last );
    void                    push_back( value_type ch );
    void                    pop_back();
    tiny_string&            append( size_type count, value_type ch );
    tiny_string&            append( const tiny_string& str );
    tiny_string&            append( const tiny_string& str, size_type pos, size_type count = npos );
    tiny_string&            append( const_pointer s, size_type count );
    tiny_string&            append( const_pointer s );
    template<class InputIterator>
    typename std::enable_if< __is_input_iterator<InputIterator>::value && !__is_forward_iterator<InputIterator>::value, tiny_string&
    >::type                 append( InputIterator first, InputIterator last );
    template<class ForwardIterator>
    typename std::enable_if< __is_forward_iterator<ForwardIterator>::value, tiny_string&
    >::type                 append( ForwardIterator first, ForwardIterator last );
    tiny_string&            append( std::initializer_list<value_type> ilist );
    tiny_string&            operator+=( const tiny_string& str );
    tiny_string&            operator+=( value_type ch );
    tiny_string&            operator+=( const_pointer s );
    tiny_string&            operator+=( std::initializer_list<value_type> ilist );
    int                     compare( const tiny_string& str ) const noexcept;
    int                     compare( size_type pos1, size_type count1, const tiny_string& str ) const;
    int                     compare( size_type pos1, size_type count1, const tiny_string& str, size_type pos2, size_type count2 = npos ) const;
    int                     compare( const_pointer s ) const;
    int                     compare( size_type pos1, size_type count1, const_pointer s ) const;
    int                     compare( size_type pos1, size_type count1, const_pointer s, size_type count2 ) const;
    tiny_string&            replace( size_type pos, size_type count, const tiny_string& str );
    tiny_string&            replace( const_iterator first, const_iterator last, const tiny_string& str );
    tiny_string&            replace( size_type pos, size_type count1, const tiny_string& str, size_type pos2, size_type count2 = npos );
    template<class Iterator>
    tiny_string&            replace( const_iterator first1, const_iterator last1, Iterator first2, Iterator last2 );
    tiny_string&            replace( size_type pos, size_type count1, const_pointer s, size_type count2 );
    tiny_string&            replace( const_iterator first, const_iterator last, const_pointer s, size_type count2 );
    tiny_string&            replace( size_type pos, size_type count1, const_pointer s);
    tiny_string&            replace( const_iterator first, const_iterator last, const_pointer s );
    tiny_string&            replace( size_type pos, size_type count1, size_type count2, value_type ch );
    tiny_string&            replace( const_iterator first, const_iterator last, size_type count2, value_type ch );
    tiny_string&            replace( const_iterator first, const_iterator last, std::initializer_list<value_type> ilist );
    tiny_string             substr( size_type pos = 0, size_type count = npos ) const;
    size_type               copy( pointer dest, size_type count, size_type pos = 0) const;
    void                    resize( size_type count );
    void                    resize( size_type count, value_type ch );    
    void                    swap( tiny_string& other )  noexcept;
    
    //////////////////////////////////////////////////////////////////////////////
    // Search
    /////////////
    size_type               find( const tiny_string& str, size_type pos = 0 )           const noexcept;
    size_type               find( const_pointer s, size_type pos, size_type count )     const noexcept;
    size_type               find( const_pointer s, size_type pos = 0 )                  const noexcept;
    size_type               find( value_type ch, size_type pos = 0 )                    const noexcept;
    size_type               rfind( const tiny_string& str, size_type pos = npos )       const noexcept;
    size_type               rfind( const_pointer s, size_type pos, size_type count )    const noexcept;
    size_type               rfind( const_pointer s, size_type pos = npos )              const noexcept;
    size_type               rfind( value_type ch, size_type pos = npos )                const noexcept;
    
private:
    static constexpr size_type __builtin_buf_size = 7; // including null-terminator
    
    struct __ctrl {
        size_type __length;
        size_type __capacity; // capacity including null-terminator
        char      __buffer[];
    };
    
    union {
        struct {
            uint8_t __info;
            char    __buffer[__builtin_buf_size];
        }        __m_builtin;
        __ctrl  *__m_ctrl;
        uint64_t __m_raw;
    };
    
    bool __is_compressed() const noexcept;
    char *__extract() noexcept;
    const char *__extract() const noexcept;
    void __construct_empty() noexcept;
    void __construct( size_type count, char ch );
    void __construct( const char *s, size_type count );
    static __ctrl *__allocate_ctrl( size_type capacity );
    void __move_to_ctrl( size_type new_capacity );
    void __grow_ctrl( size_type new_capacity );
    void __set_size( size_type new_size );
    void __ensure_capacity( size_type req_capacity );
    static unsigned __len_from_info(uint8_t _i);
    static uint8_t __len_to_info(unsigned _len);
    void __destruct() noexcept;
};

inline unsigned tiny_string::__len_from_info(uint8_t _i)
{
    return (_i & (~1)) >> 1;
}

inline uint8_t tiny_string::__len_to_info(unsigned _len)
{
    return ((_len & 0xF) << 1) | 0x1;
}

inline bool tiny_string::__is_compressed() const noexcept
{
    return (__m_builtin.__info & 1) == 1;
}

inline tiny_string::size_type tiny_string::size() const noexcept
{
    return __is_compressed() ? __len_from_info(__m_builtin.__info) : __m_ctrl->__length;
}

inline tiny_string::size_type tiny_string::length() const noexcept
{
    return size();
}

inline char *tiny_string::__extract() noexcept
{
    return __is_compressed() ? &__m_builtin.__buffer[0] : &__m_ctrl->__buffer[0];
}

inline const char *tiny_string::__extract() const noexcept
{
    return __is_compressed() ? &__m_builtin.__buffer[0] : &__m_ctrl->__buffer[0];
}

inline void tiny_string::__construct_empty() noexcept
{
    __m_raw = 1; // that's it. construction of an empty string
}

inline void tiny_string::__destruct() noexcept
{
    if(!__is_compressed())
        free(__m_ctrl);
}

inline tiny_string::tiny_string()
{
    __construct_empty();
}

template< class Iterator >
tiny_string::tiny_string( Iterator first, Iterator last )
{
    __construct_empty();
    for (; first != last; ++first)
        push_back(*first);
}

inline tiny_string::~tiny_string()
{
    __destruct();
}

inline tiny_string::const_pointer tiny_string::data() const noexcept
{
    return __extract();
}

inline tiny_string::const_pointer tiny_string::c_str() const noexcept
{
    return __extract();
}

inline tiny_string::reference tiny_string::operator[](size_type pos)
{
    return __extract()[ pos ];
}

inline tiny_string::const_reference tiny_string::operator[](size_type pos) const
{
    return __extract()[ pos ];
}

inline bool tiny_string::empty() const noexcept
{
    return size() == 0;
}

inline tiny_string::reference tiny_string::front()
{
    return operator[]( 0 );
}

inline tiny_string::const_reference tiny_string::front() const
{
    return operator[]( 0 );
}

inline tiny_string::reference tiny_string::back()
{
    return operator[]( size()-1 );
}

inline tiny_string::const_reference tiny_string::back() const
{
    return operator[]( size()-1 );
}

inline tiny_string::iterator tiny_string::begin() noexcept
{
    return __extract();
}

inline tiny_string::const_iterator tiny_string::begin() const noexcept
{
    return __extract();
}

inline tiny_string::const_iterator tiny_string::cbegin() const noexcept
{
    return __extract();
}

inline tiny_string::iterator tiny_string::end() noexcept
{
    return __extract() + size();
}

inline tiny_string::const_iterator tiny_string::end() const noexcept
{
    return __extract() + size();
}

inline tiny_string::const_iterator tiny_string::cend() const noexcept
{
    return __extract() + size();
}

inline tiny_string::reverse_iterator tiny_string::rbegin() noexcept
{
    return reverse_iterator( end() );
}

inline tiny_string::const_reverse_iterator tiny_string::rbegin() const noexcept
{
    return const_reverse_iterator( end() );
}

inline tiny_string::const_reverse_iterator tiny_string::crbegin() const noexcept
{
    return rbegin();
}

inline tiny_string::reverse_iterator tiny_string::rend() noexcept
{
    return reverse_iterator( begin() );
}

inline tiny_string::const_reverse_iterator tiny_string::rend() const noexcept
{
    return const_reverse_iterator( begin() );
}

inline tiny_string::const_reverse_iterator tiny_string::crend() const noexcept
{
    return rend();
}

inline tiny_string::size_type tiny_string::max_size() const noexcept
{
    return std::numeric_limits<size_type>::max() - 1;
}

inline tiny_string::size_type tiny_string::capacity() const noexcept
{
    return __is_compressed() ? (__builtin_buf_size - 1) : (__m_ctrl->__capacity - 1);
}

inline tiny_string& tiny_string::append( const_pointer s )
{
    return append( s, (size_type)strlen(s) );
}

template<class _InputIterator>
typename std::enable_if< tiny_string::__is_input_iterator<_InputIterator>::value && !tiny_string::__is_forward_iterator<_InputIterator>::value, tiny_string&
>::type tiny_string::append(_InputIterator __first, _InputIterator __last)
{
    for (; __first != __last; ++__first)
        push_back(*__first);
    return *this;
}

template<class _ForwardIterator>
typename std::enable_if< tiny_string::__is_forward_iterator<_ForwardIterator>::value, tiny_string&
>::type tiny_string::append(_ForwardIterator __first, _ForwardIterator __last)
{
    auto __n = size_type(std::distance(__first, __last));
    if (__n) {
        __ensure_capacity( size() + __n );
        auto _begin = begin(), _end = end();
        while( __first != __last )
            *(_end++) = *(__first++);
        *_end = 0;
        __set_size(size_type(_end - _begin));
    }
    return *this;
}

inline tiny_string& tiny_string::append( std::initializer_list<value_type> ilist )
{
    return append( ilist.begin(), size_type(ilist.size()) );
}

inline tiny_string& tiny_string::insert( size_type index, const_pointer s )
{
    return insert( index, s, size_type(strlen(s)) );
}

inline tiny_string& tiny_string::insert( size_type index, const tiny_string& str )
{
    return insert( index, str.data(), str.size() );
}

inline tiny_string::iterator tiny_string::insert( const_iterator pos, value_type ch )
{
    auto d = size_type(pos - begin());
    insert(d, 1, ch);
    return begin() + d;
}

inline tiny_string::iterator tiny_string::insert( const_iterator pos, size_type count, value_type ch )
{
    auto d = size_type(pos - begin());
    insert(d, count, ch);
    return begin() + d;
}

template<class _InputIterator>
typename std::enable_if< tiny_string::__is_input_iterator<_InputIterator>::value && !tiny_string::__is_forward_iterator<_InputIterator>::value, tiny_string::iterator
>::type tiny_string::insert( const_iterator pos, _InputIterator first, _InputIterator last )
{
    auto old_sz = size();
    auto d = size_type(pos - begin());
    for (; first != last; ++first)
        push_back(*first);
    auto p = begin();
    std::rotate(p + d, p + old_sz, p + size());
    return p + d;
}

template<class _ForwardIterator>
typename std::enable_if< tiny_string::__is_forward_iterator<_ForwardIterator>::value, tiny_string::iterator
>::type tiny_string::insert( const_iterator pos, _ForwardIterator first, _ForwardIterator last )
{
    auto _sz = size();
    auto d = size_type(pos - begin());
    auto count = size_type(std::distance(first, last));
    if (d > _sz)
        throw std::out_of_range("");
    if( count ) {
        __ensure_capacity( size() + count);
        auto _i = begin() + d;
        memmove(_i + count, _i, end() - _i + 1);
        while( first != last )
            *(_i++) = *(first++);
        __set_size(_sz + count);
    }
    return begin() + d;
}

inline tiny_string::iterator tiny_string::insert( const_iterator pos, std::initializer_list<value_type> ilist )
{
    return insert( pos, std::begin(ilist), std::end(ilist) );
}

inline tiny_string::iterator tiny_string::erase( const_iterator pos )
{
    auto d = size_type(pos - begin());
    erase( d, 1 );
    return begin() + d;
}

inline tiny_string::iterator tiny_string::erase( const_iterator first, const_iterator last )
{
    auto d = size_type(first - begin());
    erase( d, size_type(last - first) );
    return begin() + d;
}

inline void tiny_string::resize( size_type count )
{
    resize( count, value_type() );
}

inline tiny_string& tiny_string::replace( size_type pos, size_type count, const tiny_string& str )
{
    return replace( pos, count, str.data(), str.size() );
}

inline tiny_string& tiny_string::replace( const_iterator first, const_iterator last, size_type count2, value_type ch )
{
    return replace( size_type(first - begin()), size_type(last-first), count2, ch );
}

inline tiny_string& tiny_string::replace( const_iterator first, const_iterator last, const tiny_string& str )
{
    return replace( size_type(first - begin()), size_type(last-first), str );
}

inline tiny_string& tiny_string::replace( const_iterator first, const_iterator last, const_pointer s, size_type count2 )
{
    return replace( size_type(first - begin()), size_type(last-first), s, count2 );
}

inline tiny_string& tiny_string::replace( size_type pos, size_type count1, const_pointer s)
{
    return replace( pos, count1, s, size_type(strlen(s)) );
}

inline tiny_string& tiny_string::replace( const_iterator first, const_iterator last, const_pointer s )
{
    return replace( size_type(first - begin()), size_type(last-first), s );
}

template<class Iterator>
tiny_string& tiny_string::replace( const_iterator first1, const_iterator last1, Iterator first2, Iterator last2 )
{
    tiny_string str;
    for( ; first2!=last2 ; ++first2 )
        str.push_back( *first2 );
    return replace( first1, last1, str );
}

inline tiny_string& tiny_string::replace( const_iterator first, const_iterator last, std::initializer_list<value_type> ilist )
{
    return replace( first, last, std::begin(ilist), std::end(ilist) );
}

inline int tiny_string::compare( size_type pos1, size_type count1, const_pointer s ) const
{
    return compare( pos1, count1, s, size_type(strlen(s)) );
}

inline int tiny_string::compare( const_pointer s ) const
{
    return compare( size_type(0), size(), s );
}

inline int tiny_string::compare( size_type pos1, size_type count1, const tiny_string& str ) const
{
    return compare( pos1, count1, str.data(), str.size() );
}

inline int tiny_string::compare( const tiny_string& str ) const noexcept
{
    return compare( 0, size(), str.data(), str.size() );
}

inline tiny_string& tiny_string::operator+=( const tiny_string& str )
{
    return append( str );
}

inline tiny_string& tiny_string::operator+=( value_type ch )
{
    return append( size_type(1), ch );
}

inline tiny_string& tiny_string::operator+=( const_pointer s )
{
    return append( s );
}

inline tiny_string& tiny_string::operator+=( std::initializer_list<value_type> ilist )
{
    return append( ilist );
}

inline tiny_string& tiny_string::assign( size_type count, value_type ch )
{
    clear();
    return append( count, ch );
}

inline tiny_string& tiny_string::assign( const tiny_string& str )
{
    clear();
    return append( str );
}

inline tiny_string& tiny_string::assign( const tiny_string& str, size_type pos, size_type count )
{
    clear();
    return append( str, pos, count );
}

inline tiny_string& tiny_string::assign( const_pointer s, size_type count )
{
    clear();
    return append( s, count );
}

inline tiny_string& tiny_string::assign( const_pointer s )
{
    clear();
    return append( s );
}

template< class Iterator >
tiny_string& tiny_string::assign( Iterator first, Iterator last )
{
    clear();
    return append( first, last );
}

inline tiny_string& tiny_string::assign( std::initializer_list<value_type> ilist )
{
    clear();
    return append( ilist );
}

inline tiny_string& tiny_string::operator=( const tiny_string& str )
{
    return assign( str );
}

inline tiny_string& tiny_string::operator=( tiny_string&& str ) noexcept
{
    return assign( std::move(str) );
}

inline tiny_string& tiny_string::operator=( const_pointer s )
{
    return assign( s );
}

inline tiny_string& tiny_string::operator=( value_type ch )
{
    return assign( size_type(1), ch );
}

inline tiny_string& tiny_string::operator=( std::initializer_list<value_type> ilist )
{
    return assign( ilist );
}

inline tiny_string::size_type tiny_string::find( const tiny_string& str, size_type pos ) const noexcept
{
    return find( str.data(), pos, str.size() );
}

inline tiny_string::size_type tiny_string::find( const_pointer s, size_type pos ) const noexcept
{
    return find( s, pos, size_type(strlen(s)) );
}

inline tiny_string::size_type tiny_string::rfind( const tiny_string& str, size_type pos ) const noexcept
{
    return rfind( str.data(), pos, str.size() );
}

inline tiny_string::size_type tiny_string::rfind( const_pointer s, size_type pos ) const noexcept
{
    return rfind( s, pos, size_type(strlen(s)) );
}

inline tiny_string operator+( const tiny_string& lhs, const tiny_string& rhs )
{
    return tiny_string(lhs).append( rhs );
}

inline tiny_string operator+( const char* lhs, const tiny_string& rhs )
{
    return tiny_string(lhs).append( rhs );
}

inline tiny_string operator+( char lhs, const tiny_string& rhs )
{
    return tiny_string(1, lhs).append( rhs );
}

inline tiny_string operator+( const tiny_string& lhs, const char* rhs )
{
    return tiny_string(lhs).append( rhs );
}

inline tiny_string operator+( const tiny_string& lhs, char rhs )
{
    return tiny_string(lhs).append( 1, rhs );
}

inline tiny_string operator+( tiny_string&& lhs, const tiny_string& rhs )
{
    return std::move( lhs.append(rhs) );
}

inline tiny_string operator+( const tiny_string& lhs, tiny_string&& rhs )
{
    return std::move( rhs.insert(0, lhs) );
}

inline tiny_string operator+( tiny_string&& lhs, tiny_string&& rhs )
{
    return std::move( lhs.append(rhs) );
}

inline bool operator==(const tiny_string& lhs, const tiny_string& rhs) noexcept
{
    auto lhs_sz = lhs.size();
    return lhs_sz == rhs.size() && memcmp( lhs.data(), rhs.data(), lhs_sz ) == 0;
}

inline bool operator==(const char* lhs, const tiny_string& rhs) noexcept
{
    return rhs.compare(lhs) == 0;
}

inline bool operator==(const tiny_string& lhs, const char* rhs) noexcept
{
    return lhs.compare(rhs) == 0;
}

inline bool operator!=(const tiny_string& lhs, const tiny_string& rhs) noexcept
{
    return !(lhs == rhs);
}

inline bool operator!=(const char* lhs, const tiny_string& rhs) noexcept
{
    return !(lhs == rhs);
}

inline bool operator!=(const tiny_string& lhs, const char* rhs) noexcept
{
    return !(lhs == rhs);
}

inline bool operator< (const tiny_string& lhs, const tiny_string& rhs) noexcept
{
    return lhs.compare(rhs) < 0;
}

inline bool operator< (const tiny_string& lhs, const char* rhs) noexcept
{
    return lhs.compare(rhs) < 0;
}

inline bool operator< (const char* lhs, const tiny_string& rhs) noexcept
{
    return rhs.compare(lhs) > 0;
}

inline bool operator> (const tiny_string& lhs, const tiny_string& rhs) noexcept
{
    return rhs < lhs;
}

inline bool operator> (const tiny_string& lhs, const char* rhs) noexcept
{
    return rhs < lhs;
}

inline bool operator> (const char* lhs, const tiny_string& rhs) noexcept
{
    return rhs < lhs;
}

inline bool operator<=(const tiny_string& lhs, const tiny_string& rhs) noexcept
{
    return !(rhs < lhs);
}

inline bool operator<=(const tiny_string& lhs, const char* rhs) noexcept
{
    return !(rhs < lhs);
}

inline bool operator<=(const char* lhs, const tiny_string& rhs) noexcept
{
    return !(rhs < lhs);
}

inline bool operator>=(const tiny_string& lhs, const tiny_string& rhs) noexcept
{
    return !(lhs < rhs);
}

inline bool operator>=(const tiny_string& lhs, const char* rhs) noexcept
{
    return !(lhs < rhs);
}

inline bool operator>=(const char* lhs, const tiny_string& rhs) noexcept
{
    return !(lhs < rhs);
}

namespace std {
    inline void swap( tiny_string &lhs, tiny_string &rhs ) noexcept
    {
        lhs.swap(rhs);
    }
}
