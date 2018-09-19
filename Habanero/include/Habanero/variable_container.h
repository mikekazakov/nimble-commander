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

#include <assert.h>
#include <array>
#include <vector>
#include <unordered_map>

struct __variable_container_base
{
    enum class type : char
    {
        dense   = 0,
        sparse  = 1,
        common  = 2
    };
};

template <class T = int>
class variable_container
{
public:
    typedef T           value_type;
    typedef T&          reference;
    typedef const T&    const_reference;

    using type = __variable_container_base::type;
    
    /**
     * Construction/desctuction/assigning.
     */
    variable_container( type _type = type::common );
    variable_container( const T& _value );
    variable_container( T &&_value );
    variable_container( const variable_container& _rhs );
    variable_container( variable_container&& _rhs );
    ~variable_container();
    const variable_container &operator=( const variable_container& _rhs );
    const variable_container &operator=( variable_container&& _rhs );
    
    /**
     * return current container's type.
     */
    type mode() const noexcept;
    
    /**
     * reverts container to empty state with specified type.
     */
    void reset( type _type );
    
    /**
     * for common mode return common value.
     * for other modes uses at() of vector<> and unordered_map<>.
     */
    T &at(size_t _at);
    T &operator[](size_t _at);
    const T &at(size_t _at) const;
    const T &operator[](size_t _at) const;
    
    /**
     * return amount of elements inside.
     * for common mode always returns 1.
     * for other modes return size of a corresponding container.
     */
    unsigned size() const;
    
    /**
     * returns size() == 0;
     */
    bool empty() const;
    
    /**
     * Can be used only with Dense mode, ignored otherwise.
     */
    void resize( size_t _new_size );
    
    /**
     * if mode is Dense an _at is above current size -> will resize accordingly.
     * if mode is Common will ignore _at and fill common value with _value.
     */
    void insert( size_t _at, const T& _value );
    void insert( size_t _at, T&& _value );

    /**
     * for common mode return true always.
     * for sparse mode checks for presence of this item.
     * for dense mode checks vector bounds.
     */
    bool has( unsigned _at ) const;
    
    /**
     * return true if:
     * - type is common or dense
     * - type is sparse and map containst all keys from [0, size)
     */
    bool is_contiguous() const noexcept;
    
    /**
     * transforms sparse container with contiguous elements into a dense container.
     * will throw a logic_error if any element is missing ( container is non contiguous ).
     * if container isn't sparse type - will throw a logic_error.
     */
    void compress_contiguous();
    
private:
    typedef value_type                          common_type;
    typedef std::unordered_map<unsigned, T>     sparse_type;
    typedef std::vector<T>                      dense_type;
    enum {
        m_StorageSize = std::max( {sizeof(common_type), sizeof(sparse_type), sizeof(dense_type)} )
    };
    
    common_type         &Common();
    const common_type   &Common() const;
    sparse_type         &Sparse();
    const sparse_type   &Sparse() const;
    dense_type          &Dense();
    const dense_type    &Dense() const;
    
    void Construct();
    void ConstructCopy(const variable_container<T>& _rhs);
    void ConstructMove(variable_container<T>&& _rhs);
    void Destruct();
    // it would be nice to change this ugly casts to C++11-style unions, but current XCode6.4 crashes on them. check it later.
    // TODO: get rid of Common(), Sparse() and Dense() functions, move to modern union.
    std::array<char,
               m_StorageSize>   m_Storage;
    type                        m_Type;
};

template <class T>
variable_container<T>::variable_container( type _type ) :
    m_Type(_type)
{
    Construct();
}

template <class T>
variable_container<T>::variable_container( const variable_container<T>& _rhs ):
    m_Type(_rhs.m_Type)
{
    ConstructCopy(_rhs);
}

template <class T>
variable_container<T>::variable_container( variable_container<T>&& _rhs ):
    m_Type(_rhs.m_Type)
{
    ConstructMove(move(_rhs));
}

template <class T>
variable_container<T>::variable_container( const T& _value ):
    m_Type(type::common)
{
    new (&Common()) common_type( _value );
}

template <class T>
variable_container<T>::variable_container( T &&_value ):
    m_Type(type::common)
{
    new (&Common()) common_type( move(_value) );
}

template <class T>
variable_container<T>::~variable_container()
{
    Destruct();
}

template <class T>
typename variable_container<T>::type variable_container<T>::mode() const noexcept
{
    return m_Type;
}

template <class T>
void variable_container<T>::reset(type _type)
{
    *this = variable_container<T>(_type);
}

template <class T>
const variable_container<T> &variable_container<T>::operator =(const variable_container<T>& _rhs)
{
    if( m_Type != _rhs.m_Type ) {
        Destruct();
        m_Type = _rhs.m_Type;
        ConstructCopy(_rhs);
    }
    else {
        if( m_Type == type::common )
            Common() = _rhs.Common();
        else if( m_Type == type::sparse )
            Sparse() = _rhs.Sparse();
        else if( m_Type == type::dense )
            Dense() = _rhs.Dense();
    }
    return *this;
}

template <class T>
const variable_container<T> &variable_container<T>::operator =(variable_container<T>&& _rhs)
{
    if( m_Type != _rhs.m_Type ) {
        Destruct();
        m_Type = _rhs.m_Type;
        ConstructMove(move(_rhs));
    }
    else {
        if( m_Type == type::common )
            Common() = move(_rhs.Common());
        else if( m_Type == type::sparse )
            Sparse() = move(_rhs.Sparse());
        else if( m_Type == type::dense )
            Dense() = move(_rhs.Dense());
    }
    return *this;    
}

template <class T> typename variable_container<T>::common_type &variable_container<T>::Common() {
    return *reinterpret_cast<common_type*>(m_Storage.data());
}

template <class T> const typename variable_container<T>::common_type &variable_container<T>::Common() const {
    return *reinterpret_cast<const common_type*>(m_Storage.data());
}

template <class T> typename variable_container<T>::sparse_type &variable_container<T>::Sparse() {
    return *reinterpret_cast<sparse_type*>(m_Storage.data());
}

template <class T> const typename variable_container<T>::sparse_type &variable_container<T>::Sparse() const {
    return *reinterpret_cast<const sparse_type*>(m_Storage.data());
}

template <class T> typename variable_container<T>::dense_type &variable_container<T>::Dense() {
    return *reinterpret_cast<dense_type*>(m_Storage.data());
}

template <class T> const typename variable_container<T>::dense_type &variable_container<T>::Dense() const {
    return *reinterpret_cast<const dense_type*>(m_Storage.data());
}

template <class T>
void variable_container<T>::Construct()
{
    if( m_Type == type::common )
        new (&Common()) common_type;
    else if( m_Type == type::sparse )
        new (&Sparse()) sparse_type;
    else if( m_Type == type::dense )
        new (&Dense()) dense_type;
    else
        throw std::logic_error("invalid type in variable_container<T>::Contruct()");
}

template <class T>
void variable_container<T>::ConstructCopy(const variable_container<T>& _rhs)
{
    assert( m_Type == _rhs.m_Type );
    
    if( m_Type == type::common )
        new (&Common()) common_type( _rhs.Common() );
    else if( m_Type == type::sparse )
        new (&Sparse()) sparse_type( _rhs.Sparse() );
    else if( m_Type == type::dense )
        new (&Dense()) dense_type( _rhs.Dense() );
}

template <class T>
void variable_container<T>::ConstructMove(variable_container<T>&& _rhs)
{
    assert( m_Type == _rhs.m_Type );
    
    if( m_Type == type::common )
        new (&Common()) common_type( move(_rhs.Common()) );
    else if( m_Type == type::sparse )
        new (&Sparse()) sparse_type( move(_rhs.Sparse()) );
    else if( m_Type == type::dense )
        new (&Dense()) dense_type( move(_rhs.Dense()) );
}

template <class T>
void variable_container<T>::Destruct()
{
    if( m_Type == type::common )
        Common().~common_type();
    else if( m_Type == type::sparse )
        Sparse().~sparse_type();
    else if( m_Type == type::dense )
        Dense().~dense_type();
}

template <class T>
T &variable_container<T>::at(size_t _at)
{
    if( m_Type == type::common )
        return Common();
    else if( m_Type == type::dense )
        return Dense().at(_at);
    else if( m_Type == type::sparse )
        return Sparse().at((unsigned)_at);
    else
        throw std::logic_error("invalid type in variable_container<T>::at");
}

template <class T>
T &variable_container<T>::operator[](size_t _at)
{
    return at(_at);
}

template <class T>
const T &variable_container<T>::at(size_t _at) const
{
    if( m_Type == type::common )
        return Common();
    else if( m_Type == type::dense )
        return Dense().at(_at);
    else if( m_Type == type::sparse )
        return Sparse().at((unsigned)_at);
    else
        throw std::logic_error("invalid type in variable_container<T>::at");
}

template <class T>
const T &variable_container<T>::operator[](size_t _at) const
{
    return at(_at);
}

template <class T>
void variable_container<T>::resize( size_t _new_size )
{
    if( m_Type == type::dense )
        Dense().resize( _new_size );
}

template <class T>
void variable_container<T>::insert( size_t _at, const T& _value )
{
    if( m_Type == type::common ) {
        Common() = _value;
    }
    else if( m_Type == type::dense ) {
        if( Dense().size() <= _at  )
            Dense().resize( _at + 1 );
        Dense()[_at] = _value;
    }
    else if( m_Type == type::sparse ) {
        auto r = Sparse().insert( typename sparse_type::value_type( (unsigned)_at, _value ) );
        if( !r.second )
            r.first->second = _value;
    }
    else
        throw std::logic_error("invalid type in variable_container<T>::insert");
}

template <class T>
void variable_container<T>::insert( size_t _at, T&& _value )
{
    if( m_Type == type::common ) {
        Common() = move(_value);
    }
    else if( m_Type == type::dense ) {
        if( Dense().size() <= _at  )
            Dense().resize( _at + 1 );
        Dense()[_at] = move(_value);
    }
    else if( m_Type == type::sparse ) {
        auto i = Sparse().find( (unsigned)_at );
        if( i == end(Sparse()) )
            Sparse().insert( typename sparse_type::value_type( (unsigned)_at, move(_value) ) );
        else
            i->second = move(_value);
    }
    else
        throw std::logic_error("invalid type in variable_container<T>::insert");
}

template <class T>
bool variable_container<T>::has( unsigned _at ) const
{
    if( m_Type == type::common )
        return true;
    else if( m_Type == type::dense )
        return _at < Dense().size();
    else if( m_Type == type::sparse )
        return Sparse().find(_at) != end(Sparse());
    else
        throw std::logic_error("invalid type in variable_container<T>::has");
}

template <class T>
unsigned variable_container<T>::size() const
{
    if( m_Type == type::common )
        return 1;
    else if( m_Type == type::dense )
        return (unsigned)Dense().size();
    else if( m_Type == type::sparse )
        return (unsigned)Sparse().size();
    else
        throw std::logic_error("invalid type in variable_container<T>::size");
}

template <class T>
bool variable_container<T>::empty() const
{
    return size() == 0;
}

template <class T>
bool variable_container<T>::is_contiguous() const noexcept
{
    if( m_Type == type::dense || m_Type == type::common )
        return true;
    
    for( unsigned i = 0, e = size(); i != e; ++i )
        if( !has(i) )
            return false;
    
    return true;
}

template <class T>
void variable_container<T>::compress_contiguous()
{
    if( m_Type != type::sparse )
        throw std::logic_error("variable_container<T>::compress_contiguous was called for a non-sparse container");
    
    variable_container<T> new_dense( type::dense );
    
    unsigned i = 0, e = size();
    auto &dense = new_dense.Dense();
    dense.reserve( e );
    
    auto &sparse = Sparse();
    for(; i != e; ++i  )
        dense.emplace_back( move(sparse.at(i)) );
    
    *this = move(new_dense);
}
