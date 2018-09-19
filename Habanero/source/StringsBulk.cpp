/* Copyright (c) 2017 Michael G. Kazakov
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
#include <Habanero/StringsBulk.h>
#include <assert.h>

namespace hbn {

////////////////////////////////////////////////////////////////////////////////////////////////////
// StringsBulk::Ctrl
////////////////////////////////////////////////////////////////////////////////////////////////////
struct StringsBulk::Ctrl
{
    Ctrl() = delete;
    ~Ctrl() = delete;
    
    size_t bytes;
    size_t count;
    // offsets: count * 4 bytes
    // null-terminated strings
    
    inline const uint32_t *Offsets() const noexcept {
        const auto raw = reinterpret_cast<const char *>(this);
        return reinterpret_cast<const uint32_t*>(raw + sizeof(Ctrl));
    }
    
    inline const char *Get(size_t _index) const noexcept {
        return reinterpret_cast<const char *>(this) + Offsets()[_index];
    }
    
    inline size_t StrLen(size_t _index) const noexcept {
        if( _index + 1 < count )
            return Offsets()[_index + 1] - Offsets()[_index] - 1;
        else
            return bytes - Offsets()[_index] - 1;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////
// StringsBulk
////////////////////////////////////////////////////////////////////////////////////////////////////
StringsBulk::StringsBulk() noexcept:
    m_Count(0),
    m_Ctrl(nullptr)
{
    static_assert( sizeof(StringsBulk) == 16 );
    static_assert( sizeof(Ctrl) == 16 );
    static_assert( sizeof(Iterator) == 16 );
}

StringsBulk::StringsBulk(const StringsBulk& _rhs)
{
    if( _rhs.empty() ) {
        m_Count = 0;
        m_Ctrl = nullptr;
    }
    else {
        assert( _rhs.m_Ctrl != nullptr );
        assert( _rhs.m_Ctrl->count == _rhs.m_Count );
        const auto ctrl = reinterpret_cast<Ctrl*>( malloc(_rhs.m_Ctrl->bytes) );
        if( ctrl == nullptr )
            throw std::bad_alloc();
        
        memcpy(ctrl, _rhs.m_Ctrl, _rhs.m_Ctrl->bytes);
        m_Ctrl = ctrl;
        m_Count = _rhs.m_Count;
    }
}

StringsBulk::StringsBulk(StringsBulk&& _rhs) noexcept:
    m_Count(_rhs.m_Count),
    m_Ctrl(_rhs.m_Ctrl)
{
    _rhs.m_Count = 0;
    _rhs.m_Ctrl = nullptr;
}

StringsBulk::StringsBulk(size_t _strings_amount, Ctrl *_data) noexcept:
    m_Count(_strings_amount),
    m_Ctrl(_data)
{
}
    
StringsBulk::~StringsBulk()
{
    if( !empty() )
        free(m_Ctrl);
}

StringsBulk &StringsBulk::operator=(const StringsBulk& _rhs)
{
    if( &_rhs == this )
        return *this;
    
    if( _rhs.empty() ) {
        if( !empty() ) {
            free(m_Ctrl);
            m_Count = 0;
            m_Ctrl = nullptr;
        }
    }
    else {
        assert( _rhs.m_Ctrl != nullptr );
        assert( _rhs.m_Ctrl->count == _rhs.m_Count );
        
        const auto ctrl = reinterpret_cast<Ctrl*>( malloc(_rhs.m_Ctrl->bytes) );
        if( ctrl == nullptr )
            throw std::bad_alloc();
        
        memcpy(ctrl, _rhs.m_Ctrl, _rhs.m_Ctrl->bytes);
        
        if( !empty() )
            free(m_Ctrl);
        
        m_Ctrl = ctrl;
        m_Count = _rhs.m_Count;
    }
    return *this;
}
    
StringsBulk &StringsBulk::operator=(StringsBulk&& _rhs) noexcept
{
    if( &_rhs == this )
        return *this;
    
    if( !empty() )
        free(m_Ctrl);
    m_Count = _rhs.m_Count;
    m_Ctrl = _rhs.m_Ctrl;
    _rhs.m_Count = 0;
    _rhs.m_Ctrl = nullptr;
    return *this;
}
    
bool StringsBulk::empty() const noexcept
{
    return size() == 0;
}
    
size_t StringsBulk::size() const noexcept
{
    return m_Count;
}
    
const char *StringsBulk::at(size_t _index) const
{
    if( _index >= m_Count )
        throw std::out_of_range("StringsBulk::at(size_t _index): invalid index");
    
    return (*this)[_index];
}
    
const char *StringsBulk::operator[](size_t _index) const
{
    assert( _index < m_Count );
    return m_Ctrl->Get(_index);
}
 
const char *StringsBulk::front() const noexcept
{
    assert( !empty() );
    return operator[](0);
}
    
const char *StringsBulk::back() const noexcept
{
    assert( !empty() );
    return operator[](m_Count-1);
}
    
StringsBulk::Iterator StringsBulk::begin() const noexcept
{
    StringsBulk::Iterator i;
    i.m_Index = 0;
    i.m_Ctrl = m_Ctrl;
    return i;
}
    
StringsBulk::Iterator StringsBulk::end() const noexcept
{
    StringsBulk::Iterator i;
    i.m_Index = m_Count;
    i.m_Ctrl = m_Ctrl;
    return i;
}
    
size_t StringsBulk::string_length(size_t _index) const
{
    if( _index >= m_Count )
        throw std::out_of_range("StringsBulk::string_length(size_t _index): invalid index");
    return m_Ctrl->StrLen(_index);
}

StringsBulk::Ctrl *StringsBulk::Allocate( size_t _number_of_strings, size_t _total_chars )
{
    assert( _number_of_strings != 0 );
    
    const size_t bytes = sizeof(Ctrl) +
    sizeof(uint32_t) * _number_of_strings +
    _total_chars;
    
    const auto ctrl = reinterpret_cast<Ctrl*>( malloc(bytes) );
    if( ctrl == nullptr )
        throw std::bad_alloc();
    
    ctrl->bytes = bytes;
    ctrl->count = _number_of_strings;
    
    return ctrl;
}
    
bool operator==(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept
{
    auto comp = [](const char *_1, const char *_2){
        return strcmp(_1, _2) == 0;
    };
    return _lhs.size() == _rhs.size() &&
            std::equal( _lhs.begin(), _lhs.end(), _rhs.begin(), comp );
}
    
bool operator!=(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept
{
    return !(_lhs == _rhs);
}

template <class _InputIterator1, class _InputIterator2>
static bool lexicographical_strcmp_compare(_InputIterator1 __first1, _InputIterator1 __last1,
                                           _InputIterator2 __first2, _InputIterator2 __last2)
{
    for(; __first2 != __last2; ++__first1, ++__first2 ) {
        if( __first1 == __last1 )
            return true;
        
        const auto cmp = strcmp( *__first1, *__first2 );
        if( cmp < 0 )
            return true;
        if( cmp > 0 )
            return false;
    }
    return false;
}
    
bool operator <(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept
{
    return lexicographical_strcmp_compare( _lhs.begin(), _lhs.end(), _rhs.begin(), _rhs.end() );
}
    
bool operator <=(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept
{
    return !(_rhs < _lhs);
}
    
bool operator >(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept
{
    return _rhs < _lhs;
}
    
bool operator >=(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept
{
    return !(_lhs < _rhs);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// StringsBulk::Iterator
////////////////////////////////////////////////////////////////////////////////////////////////////
void StringsBulk::Iterator::swap(Iterator &_rhs) noexcept
{
    std::swap( m_Index, _rhs.m_Index );
    std::swap( m_Ctrl, _rhs.m_Ctrl );
}
    
const char * StringsBulk::Iterator::operator*() const noexcept
{
    assert( m_Ctrl && m_Ctrl->count > m_Index );
    return m_Ctrl->Get(m_Index);
}

const char *StringsBulk::Iterator::operator[](long _d) const noexcept
{
    return *(*this + _d);
}
    
StringsBulk::Iterator &StringsBulk::Iterator::operator++() noexcept
{
    assert( m_Ctrl && m_Ctrl->count > m_Index );
    ++m_Index;
    return *this;
}

StringsBulk::Iterator StringsBulk::Iterator::operator++(int) noexcept
{
    auto t = *this;
    operator++();
    return t;
}

StringsBulk::Iterator &StringsBulk::Iterator::operator--() noexcept
{
    assert(m_Index > 0);
    --m_Index;
    return *this;
}
    
StringsBulk::Iterator StringsBulk::Iterator::operator--(int) noexcept
{
    auto t = *this;
    operator++();
    return t;
}

bool StringsBulk::Iterator::operator==(const Iterator& _rhs) const noexcept
{
    return m_Index == _rhs.m_Index;
}
    
bool StringsBulk::Iterator::operator !=(const Iterator& _rhs) const noexcept
{
    return !operator==(_rhs);
}

bool StringsBulk::Iterator::operator<(const Iterator& _rhs) const noexcept
{
    return m_Index < _rhs.m_Index;
}
    
bool StringsBulk::Iterator::operator<=(const Iterator& _rhs) const noexcept
{
    return m_Index <= _rhs.m_Index;
}
    
bool StringsBulk::Iterator::operator>(const Iterator& _rhs) const noexcept
{
    return m_Index > _rhs.m_Index;
}
    
bool StringsBulk::Iterator::operator>=(const Iterator& _rhs) const noexcept
{
    return m_Index >= _rhs.m_Index;
}
    
StringsBulk::Iterator &StringsBulk::Iterator::operator+=(long _d) noexcept
{
    if( _d == 0 )
        return *this;
    
    assert( m_Ctrl && long(m_Index) + _d >= 0 && long(m_Index) + _d <= m_Ctrl->count );
    m_Index = m_Index + _d;
    return *this;
}

StringsBulk::Iterator &StringsBulk::Iterator::operator-=(long _d) noexcept
{
    if( _d == 0 )
        return *this;
    
    assert( m_Ctrl && long(m_Index) + _d >= 0 && long(m_Index) + _d <= m_Ctrl->count );
    m_Index = m_Index - _d;
    return *this;
}

long StringsBulk::Iterator::operator-(const Iterator&_rhs) noexcept
{
    return long(m_Index) - long(_rhs.m_Index);
}
 
StringsBulk::Iterator operator+(StringsBulk::Iterator _i, long _n) noexcept
{
    _i += _n;
    return _i;
}
    
StringsBulk::Iterator operator+(long _n, StringsBulk::Iterator _i) noexcept
{
    _i += _n;
    return _i;
}

StringsBulk::Iterator operator-(StringsBulk::Iterator _i, long _n) noexcept
{
    _i -= _n;
    return _i;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// StringsBulk::NonOwningBuilder
////////////////////////////////////////////////////////////////////////////////////////////////////
StringsBulk::NonOwningBuilder::~NonOwningBuilder()
{
}
            
void StringsBulk::NonOwningBuilder::Add(std::string_view _s)
{
    m_Strings.emplace_back( _s );
}

size_t StringsBulk::NonOwningBuilder::Size() const noexcept
{
    return m_Strings.size();
}
            
bool StringsBulk::NonOwningBuilder::Empty() const noexcept
{
    return Size() == 0;
}

StringsBulk StringsBulk::NonOwningBuilder::Build() const
{
    if( m_Strings.empty() )
        return {};
    
    const auto strings_num = m_Strings.size();
    const auto total_chars = TotalBytesForChars();
    
    const auto ctrl = StringsBulk::Allocate(strings_num, total_chars);
    auto offsets = reinterpret_cast<uint32_t*>(reinterpret_cast<char *>(ctrl) +
                                               sizeof(StringsBulk::Ctrl));
    char *storage = reinterpret_cast<char *>(ctrl) +
                    sizeof(StringsBulk::Ctrl) +
                    sizeof(uint32_t) * strings_num;
    for( size_t index = 0; index < strings_num; ++index ) {
        offsets[index] = uint32_t(storage - reinterpret_cast<char *>(ctrl));
        const auto string_bytes = m_Strings[index].length();
        memcpy( storage, m_Strings[index].data(), string_bytes );
        storage[string_bytes] = 0;
        storage += string_bytes + 1;
    }
    
    return StringsBulk{strings_num, ctrl};
}
            
size_t StringsBulk::NonOwningBuilder::TotalBytesForChars() const noexcept
{
    size_t total_chars = 0;
    for( const auto &s: m_Strings )
        total_chars += s.length() + 1;
    return total_chars;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// StringsBulkBuilder
////////////////////////////////////////////////////////////////////////////////////////////////////
StringsBulk::Builder::~Builder()
{
}
    
void StringsBulk::Builder::Add(std::string _s)
{
    m_Strings.emplace_back( std::move(_s) );
}
    
size_t StringsBulk::Builder::Size() const noexcept
{
    return m_Strings.size();
}
    
bool StringsBulk::Builder::Empty() const noexcept
{
    return Size() == 0;
}

StringsBulk StringsBulk::Builder::Build() const
{
    if( m_Strings.empty() )
        return {};
    
    const auto strings_num = m_Strings.size();
    const auto total_chars = TotalBytesForChars();
    
    const auto ctrl = StringsBulk::Allocate(strings_num, total_chars);
    auto offsets = reinterpret_cast<uint32_t*>(reinterpret_cast<char *>(ctrl) +
                                               sizeof(StringsBulk::Ctrl));
    char *storage = reinterpret_cast<char *>(ctrl) +
                    sizeof(StringsBulk::Ctrl) +
                    sizeof(uint32_t) * strings_num;
    for( size_t index = 0; index < strings_num; ++index ) {
        offsets[index] = uint32_t(storage - reinterpret_cast<char *>(ctrl));
        const auto string_bytes = m_Strings[index].length() + 1;
        memcpy( storage, m_Strings[index].data(), string_bytes);
        storage += string_bytes;
    }
    
    return StringsBulk{strings_num, ctrl};
}
    
size_t StringsBulk::Builder::TotalBytesForChars() const noexcept
{
    size_t total_chars = 0;
    for( const auto &s: m_Strings )
        total_chars += s.length() + 1;
    return total_chars;
}
    
}
