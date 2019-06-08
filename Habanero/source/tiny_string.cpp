// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/tiny_string.h>
#include <assert.h>
#include <new>
#include <string>
#include <stdexcept>
#include <algorithm>

using namespace std;

static_assert( sizeof(void*) == sizeof(uint64_t), "invalid arch" );
static_assert( sizeof(tiny_string) == 8, "invalid arch" );
static const uint32_t __min_free_storage = 24; // 24+8 = min 32 bytes for allocation

tiny_string::tiny_string( size_type count, char ch )
{
    __construct(count, ch);
}

tiny_string::tiny_string(const_pointer s)
{
    __construct(s, (size_type)strlen(s));
}

tiny_string::tiny_string(const_pointer s, size_type count)
{
    __construct(s, count);
}

tiny_string::tiny_string(const tiny_string &s)
{
    __construct(s.c_str(), s.length());
}

tiny_string::tiny_string(tiny_string &&s) noexcept
{
    __m_raw = s.__m_raw;
    s.__construct_empty();
}

tiny_string::tiny_string( const tiny_string& other, size_type pos, size_type count )
{
    auto str_sz = other.size();
    if (pos > str_sz)
        throw out_of_range("");
    __construct(other.data() + pos, std::min( count, str_sz - pos ) );
}

tiny_string::tiny_string( std::initializer_list<value_type> init )
{
    __construct( init.begin(), size_type(init.size()) );
}

tiny_string::tiny_string( const std::string &s )
{
    __construct( s.data(), size_type(s.size()) );
}

void tiny_string::__construct( size_type count, char ch )
{
    if( count < __builtin_buf_size ) {
        __m_builtin.__info = __len_to_info((unsigned)count);
        for(unsigned i = 0; i < count; ++i)
            __m_builtin.__buffer[i] = ch;
        __m_builtin.__buffer[count] = 0;
    }
    else {
        __m_ctrl = __allocate_ctrl( count );
        for(unsigned i = 0; i < count; ++i)
            __m_ctrl->__buffer[i] = ch;
        __m_ctrl->__buffer[count] = 0;
        __m_ctrl->__length = count;
    }
}

void tiny_string::__construct( const char *_s, size_type _count )
{
    if( _count < __builtin_buf_size ) {
        __m_builtin.__info = __len_to_info((unsigned)_count);
        for(unsigned i = 0; i < _count; ++i)
            __m_builtin.__buffer[i] = _s[i];
        __m_builtin.__buffer[_count] = 0;
    }
    else {
        __m_ctrl = __allocate_ctrl( _count );
        memcpy( &__m_ctrl->__buffer[0], _s,_count );
        __m_ctrl->__buffer[_count] = 0;
        __m_ctrl->__length = _count;
    }
}

tiny_string::__ctrl *tiny_string::__allocate_ctrl(size_type capacity)
{
    // any buff_len alignment here?
    auto sz = offsetof(__ctrl, __buffer) + capacity + 1;
    if(sz < __min_free_storage)
        sz = __min_free_storage;
    auto c = (__ctrl *) malloc(sz);
    if(c == nullptr)
        throw bad_alloc();
    c->__capacity = uint32_t(sz - offsetof(__ctrl, __buffer));
    c->__length = 0;
    return c;
}

tiny_string::reference tiny_string::at(size_type pos)
{
    if(pos >= size())
        throw out_of_range("");
    return operator[](pos);
}

tiny_string::const_reference tiny_string::at(size_type pos) const
{
    if(pos >= size())
        throw out_of_range("");
    return operator[](pos);
}

void tiny_string::reserve( size_type new_cap )
{
    if( new_cap <= capacity() )
        return shrink_to_fit();
    
    if( __is_compressed() )
        return __move_to_ctrl(new_cap);
    
    __grow_ctrl( new_cap );
}

void tiny_string::__move_to_ctrl( size_type new_capacity )
{
    assert( __is_compressed() );
    auto cur_size = size();
    assert( new_capacity > cur_size );
    auto ctrl = __allocate_ctrl(new_capacity);
    memcpy(&ctrl->__buffer[0], &__m_builtin.__buffer[0], cur_size + 1);
    ctrl->__length = cur_size;
    __m_ctrl = ctrl;
}

void tiny_string::__grow_ctrl( size_type new_capacity )
{
    assert( !__is_compressed() );
    assert( new_capacity > capacity() );
    auto min_grow = offsetof(__ctrl, __buffer) + __m_ctrl->__capacity * 2;
    auto req = offsetof(__ctrl, __buffer) + new_capacity + 1;
    if(req < min_grow)
        req = min_grow;
    auto c = (__ctrl *) realloc(__m_ctrl, req);
    if(c == nullptr)
        throw bad_alloc();
    c->__capacity = uint32_t(req - offsetof(__ctrl, __buffer));
    __m_ctrl = c;
}

inline void tiny_string::__set_size( size_type new_size )
{
    if(__is_compressed())
        __m_builtin.__info = __len_to_info(new_size);
    else
        __m_ctrl->__length = size_type(new_size);
}

inline void tiny_string::__ensure_capacity( size_type req_capacity )
{
    if(req_capacity > capacity()) {
        if( __is_compressed() )
            __move_to_ctrl(req_capacity);
        else
            __grow_ctrl(req_capacity);
    }
}

void tiny_string::shrink_to_fit()
{
    if( !__is_compressed() ) {
        tiny_string tmp(*this);
        assign( move(tmp) );
    }
}

void tiny_string::clear() noexcept
{
    if(__is_compressed())
        __construct_empty();
    else {
        assert(__m_ctrl->__capacity > 0);
        __m_ctrl->__length = 0;
        __m_ctrl->__buffer[0] = 0;
    }
}

void tiny_string::push_back( value_type ch )
{
    __ensure_capacity( size() + 1 );
    
    auto _begin = begin(), _end = end();
    *(_end++) = ch;
    *_end = 0;
    __set_size(size_type(_end - _begin));
}

void tiny_string::pop_back()
{
    auto _begin = begin(), _end = end();
    if(_begin == _end)
        throw out_of_range("");
    *(--_end) = 0;
    __set_size(size_type(_end - _begin));
}

tiny_string& tiny_string::append( size_type count, value_type ch )
{
    if(count) {
        __ensure_capacity( size() + count);
        auto _begin = begin(), _end = end();
        while( count-- )
            *(_end++) = ch;
        *_end = 0;
        __set_size(size_type(_end - _begin));
    }
    return *this;
}

tiny_string& tiny_string::append( const_pointer s, size_type count )
{
    if(count) {
        __ensure_capacity( size() + count);
        auto _begin = begin(), _end = end();
        while( count-- )
            *(_end++) = *(s++);
        *_end = 0;
        __set_size(size_type(_end - _begin));
    }
    return *this;
}

tiny_string& tiny_string::append( const tiny_string& str )
{
    auto _str_size = str.size();
    if(_str_size) {
        auto _my_size = size();
        __ensure_capacity( _my_size + _str_size );
        memcpy(end(), str.c_str(), _str_size + 1);
        __set_size( _my_size + _str_size );
    }
    return *this;
}

tiny_string& tiny_string::append( const tiny_string& str, size_type pos, size_type count )
{
    auto _sz = str.size();
    if (pos > _sz)
        throw out_of_range("");
    return append( str.data() + pos, std::min(count, _sz - pos) );
}

tiny_string& tiny_string::insert( size_type index, size_type count, value_type ch )
{
    auto _sz = size();
    if (index > _sz)
        throw out_of_range("");
    if( count ) {
        __ensure_capacity( size() + count);
        auto _i = begin() + index;
        memmove(_i + count, _i, end() - _i + 1);
        _sz += count;
        while( count-- )
            *(_i++) = ch;
        __set_size(_sz);
    }
    return *this;
}

tiny_string& tiny_string::insert( size_type index, const_pointer s, size_type count )
{
    auto _sz = size();
    if (index > _sz)
        throw out_of_range("");
    if( count ) {
        __ensure_capacity( size() + count);
        auto _i = begin() + index;
        memmove(_i + count, _i, end() - _i + 1);
        memcpy(_i, s, count);
        __set_size(_sz + count);
    }
    return *this;
}

tiny_string& tiny_string::insert( size_type index, const tiny_string& str, size_type index_str, size_type count)
{
    size_type str_sz = str.size();
    if(index_str > str_sz)
        throw out_of_range("");
    return insert(index, str.data() + index_str, std::min(count, str_sz - index_str));
}

tiny_string& tiny_string::erase( size_type index, size_type count )
{
    auto _sz = size();
    if(index > _sz)
        throw out_of_range("");
    if( count ) {
        count = std::min(count, _sz - index);
        auto p = begin() + index;
        memmove(p, p+count, _sz - index - count + 1);
        __set_size(_sz - count);
    }
    return *this;
}

void tiny_string::swap( tiny_string& other ) noexcept
{
    std::swap(__m_raw, other.__m_raw);
}

void tiny_string::resize( size_type count, value_type ch )
{
    auto sz = size();
    if(count > sz)
        append(count - sz, ch);
    else {
        begin()[count] = 0;
        __set_size(count);
    }
}

tiny_string::size_type tiny_string::copy( pointer dest, size_type count, size_type pos ) const
{
    auto sz = size();
    if(pos > sz)
        throw out_of_range("");
    auto len = std::min(count, sz - pos);
    memcpy(dest, data()+pos, len);
    return len;
}

tiny_string tiny_string::substr( size_type pos, size_type count ) const
{
    return tiny_string(*this, pos, count);
}

tiny_string& tiny_string::replace( size_type pos, size_type count1, const const_pointer s, size_type count2 )
{
    size_type sz = size();
    if(pos > sz)
        throw out_of_range("");
    count1 = std::min(count1, sz - pos);
    __ensure_capacity( sz - count1 + count2 );
 
    auto p = begin();
    if( count1 != count2 ) {
        auto n_move = sz - pos - count1;
        if(n_move != 0) {
            if (count1 > count2) {
                memmove( p + pos, s, count2 );
                memmove( p + pos + count2, p + pos + count1, n_move );
            }
            else {
                memmove( p + pos + count2, p + pos + count1, n_move );
                memmove( p + pos, s, count2 );
            }
        }
        else {
            memmove( p + pos, s, count2 );
        }
    }
    else {
        memmove( p + pos, s, count2 );
    }
    
    sz = sz + count2 - count1;
    p[sz] = 0;
    __set_size(sz);
    return *this;
}

tiny_string& tiny_string::replace( size_type pos, size_type count1, const tiny_string& str, size_type pos2, size_type count2)
{
    auto sz = str.size();
    if(pos2 > sz)
        throw out_of_range("");
    count2 = std::min(count2, sz - pos2);
    return replace(pos, count1, str.data() + pos2, count2);
}

tiny_string& tiny_string::replace( size_type pos, size_type count1, size_type count2, value_type ch )
{
    auto sz = size();
    if(pos > sz)
        throw out_of_range("");
    count1 = std::min(count1, sz - pos);
    __ensure_capacity( sz - count1 + count2 );
    
    auto p = begin();
    if( count1 != count2 ) {
        auto n_move = sz - pos - count1;
        if(n_move != 0) {
            if (count1 > count2) {
                memset(p + pos, ch, count2 );
                memmove( p + pos + count2, p + pos + count1, n_move );
            }
            else {
                memmove( p + pos + count2, p + pos + count1, n_move );
                memset( p + pos, ch, count2 );
            }
        }
        else {
            memset( p + pos, ch, count2 );
        }
    }
    else {
        memset( p + pos, ch, count2 );
    }
    
    sz = sz + count2 - count1;
    p[sz] = 0;
    __set_size(sz);
    return *this;
}

int tiny_string::compare( size_type pos1, size_type count1, const_pointer s, size_type count2 ) const
{
    auto sz = size();
    if (pos1 > sz)
        throw out_of_range("");
    auto len = std::min(count1, sz - pos1);
    int r = traits_type::compare(data() + pos1, s, std::min(len, count2));
    if (r == 0) {
        if (len < count2)
            r = -1;
        else if (len > count2)
            r = 1;
    }
    return r;
}

int tiny_string::compare( size_type pos1, size_type count1, const tiny_string& str, size_type pos2, size_type count2 ) const
{
    auto sz = str.size();
    if(pos2 > sz)
        throw out_of_range("");
    return compare(pos1, count1, str.data() + pos2, std::min(count2, sz - pos2));
}

tiny_string& tiny_string::assign( tiny_string&& str ) noexcept
{
    __destruct();
    __m_raw = str.__m_raw;
    str.__construct_empty();
    return *this;
}

tiny_string::size_type tiny_string::find( const_pointer s, size_type pos, size_type count ) const noexcept
{
    auto sz = size();
    if (pos > sz || sz - pos < count)
        return npos;
    if (count == 0)
        return pos;
    auto p = data();
    auto r = std::search(p + pos, p + sz, s, s + count);
    if (r == p + sz)
        return npos;
    return size_type(r - p);
}

tiny_string::size_type tiny_string::find( value_type ch, size_type pos ) const noexcept
{
    auto sz = size();
    if (pos > sz)
        return npos;
    auto p = data();
    auto r = std::find(p + pos, p + sz, ch);
    if (r == p + sz)
        return npos;
    return size_type(r - p);
}

tiny_string::size_type tiny_string::rfind( const_pointer s, size_type pos, size_type count ) const noexcept
{
    auto sz = size();
    pos = std::min(pos, sz);
    if (count < sz - pos)
       pos += count;
    else
        pos = sz;
    auto p = data();
    auto r = std::find_end(p, p + pos, s, s + count);
    if (count > 0 && r == p + pos)
        return npos;
    return size_type(r - p);
}

tiny_string::size_type tiny_string::rfind( value_type ch, size_type pos ) const noexcept
{
    auto sz = size();
    if (sz) {
        if (pos < sz)
            ++pos;
        else
            pos = sz;
        auto p = data();
        for ( auto ps = p + pos; ps != p; )
            if( *(--ps) ==  ch )
                return size_type(ps - p);
    }
    return npos;
}
