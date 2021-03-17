// Copyright (C) 2015-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <cassert>
#include <array>
#include <vector>
#include <robin_hood.h>

namespace nc::base {

namespace detail {

struct variable_container_base {
    enum class type : char
    {
        dense = 0,
        sparse = 1,
        common = 2
    };
};

} // namespace detail

template <class T = int>
class variable_container
{
public:
    typedef T value_type;
    typedef T &reference;
    typedef const T &const_reference;

    using type = detail::variable_container_base::type;

    /**
     * Construction/desctuction/assigning.
     */
    variable_container(type _type = type::common);
    variable_container(const T &_value);
    variable_container(T &&_value);
    variable_container(const variable_container &_rhs);
    variable_container(variable_container &&_rhs) noexcept;
    ~variable_container();
    const variable_container &operator=(const variable_container &_rhs);
    const variable_container &operator=(variable_container &&_rhs) noexcept;

    /**
     * return current container's type.
     */
    type mode() const noexcept;

    /**
     * reverts container to empty state with specified type.
     */
    void reset(type _type);

    /**
     * for common mode return common value.
     * for other modes uses at() of vector<> and unordered_map<>.
     */
    T &at(size_t _at);
    const T &at(size_t _at) const;

    /**
     * for common mode return common value.
     * for dense mode uses vector<>::operator[].
     * for sparse mode uses unordered_map<>::find.
     * precondition: the element must exist.
     */
    T &operator[](size_t _at) noexcept;
    const T &operator[](size_t _at) const noexcept;

    /**
     * return amount of elements inside.
     * for common mode always returns 1.
     * for other modes return size of a corresponding container.
     */
    size_t size() const noexcept;

    /**
     * returns size() == 0;
     */
    bool empty() const noexcept;

    /**
     * Can be used only with Dense mode, ignored otherwise.
     */
    void resize(size_t _new_size);

    /**
     * if mode is Dense an _at is above current size -> will resize accordingly.
     * if mode is Common will ignore _at and fill common value with _value.
     */
    void insert(size_t _at, const T &_value);
    void insert(size_t _at, T &&_value);

    /**
     * for common mode return true always.
     * for sparse mode checks for presence of this item.
     * for dense mode checks vector bounds.
     */
    bool has(size_t _at) const noexcept;

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
    using common_type = value_type;
    //    using sparse_type = std::unordered_map<unsigned, T>;
    using sparse_type = robin_hood::unordered_map<size_t, T>;
    using dense_type = std::vector<T>;
    static constexpr std::size_t m_StorageSize =
        std::max({sizeof(common_type), sizeof(sparse_type), sizeof(dense_type)});

    common_type &Common();
    const common_type &Common() const;
    sparse_type &Sparse();
    const sparse_type &Sparse() const;
    dense_type &Dense();
    const dense_type &Dense() const;

    void Construct();
    void ConstructCopy(const variable_container<T> &_rhs);
    void ConstructMove(variable_container<T> &&_rhs);
    void Destruct();
    // it would be nice to change this ugly casts to C++11-style unions, but current XCode6.4
    // crashes on them. check it later.
    // TODO: get rid of Common(), Sparse() and Dense() functions, move to modern union.
    std::array<char, m_StorageSize> m_Storage;
    type m_Type;
};

template <class T>
variable_container<T>::variable_container(type _type) : m_Type(_type)
{
    Construct();
}

template <class T>
variable_container<T>::variable_container(const variable_container<T> &_rhs) : m_Type(_rhs.m_Type)
{
    ConstructCopy(_rhs);
}

template <class T>
variable_container<T>::variable_container(variable_container<T> &&_rhs) noexcept
    : m_Type(_rhs.m_Type)
{
    ConstructMove(std::move(_rhs));
}

template <class T>
variable_container<T>::variable_container(const T &_value) : m_Type(type::common)
{
    new(&Common()) common_type(_value);
}

template <class T>
variable_container<T>::variable_container(T &&_value) : m_Type(type::common)
{
    new(&Common()) common_type(move(_value));
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
const variable_container<T> &variable_container<T>::operator=(const variable_container<T> &_rhs)
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
const variable_container<T> &variable_container<T>::operator=(variable_container<T> &&_rhs) noexcept
{
    if( m_Type != _rhs.m_Type ) {
        Destruct();
        m_Type = _rhs.m_Type;
        ConstructMove(std::move(_rhs));
    }
    else {
        if( m_Type == type::common )
            Common() = std::move(_rhs.Common());
        else if( m_Type == type::sparse )
            Sparse() = std::move(_rhs.Sparse());
        else if( m_Type == type::dense )
            Dense() = std::move(_rhs.Dense());
    }
    return *this;
}

template <class T>
typename variable_container<T>::common_type &variable_container<T>::Common()
{
    return *reinterpret_cast<common_type *>(m_Storage.data());
}

template <class T>
const typename variable_container<T>::common_type &variable_container<T>::Common() const
{
    return *reinterpret_cast<const common_type *>(m_Storage.data());
}

template <class T>
typename variable_container<T>::sparse_type &variable_container<T>::Sparse()
{
    return *reinterpret_cast<sparse_type *>(m_Storage.data());
}

template <class T>
const typename variable_container<T>::sparse_type &variable_container<T>::Sparse() const
{
    return *reinterpret_cast<const sparse_type *>(m_Storage.data());
}

template <class T>
typename variable_container<T>::dense_type &variable_container<T>::Dense()
{
    return *reinterpret_cast<dense_type *>(m_Storage.data());
}

template <class T>
const typename variable_container<T>::dense_type &variable_container<T>::Dense() const
{
    return *reinterpret_cast<const dense_type *>(m_Storage.data());
}

template <class T>
void variable_container<T>::Construct()
{
    if( m_Type == type::common )
        new(&Common()) common_type;
    else if( m_Type == type::sparse )
        new(&Sparse()) sparse_type;
    else if( m_Type == type::dense )
        new(&Dense()) dense_type;
}

template <class T>
void variable_container<T>::ConstructCopy(const variable_container<T> &_rhs)
{
    assert(m_Type == _rhs.m_Type);

    if( m_Type == type::common )
        new(&Common()) common_type(_rhs.Common());
    else if( m_Type == type::sparse )
        new(&Sparse()) sparse_type(_rhs.Sparse());
    else if( m_Type == type::dense )
        new(&Dense()) dense_type(_rhs.Dense());
}

template <class T>
void variable_container<T>::ConstructMove(variable_container<T> &&_rhs)
{
    assert(m_Type == _rhs.m_Type);

    if( m_Type == type::common )
        new(&Common()) common_type(std::move(_rhs.Common()));
    else if( m_Type == type::sparse )
        new(&Sparse()) sparse_type(std::move(_rhs.Sparse()));
    else if( m_Type == type::dense )
        new(&Dense()) dense_type(std::move(_rhs.Dense()));
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
        return Sparse().at(_at);
}

template <class T>
T &variable_container<T>::operator[](size_t _at) noexcept
{
    if( m_Type == type::common ) {
        return Common();
    }
    else if( m_Type == type::dense ) {
        assert(_at < Dense().size());
        return Dense()[_at];
    }
    else { // if( m_Type == type::sparse )
        auto it = Sparse().find(_at);
        assert(it != Sparse().end());
        return it->second;
    }
}

template <class T>
const T &variable_container<T>::at(size_t _at) const
{
    if( m_Type == type::common )
        return Common();
    else if( m_Type == type::dense )
        return Dense().at(_at);
    else // if( m_Type == type::sparse )
        return Sparse().at(_at);
}

template <class T>
const T &variable_container<T>::operator[](size_t _at) const noexcept
{
    if( m_Type == type::common ) {
        return Common();
    }
    else if( m_Type == type::dense ) {
        assert(_at < Dense().size());
        return Dense()[_at];
    }
    else { // if( m_Type == type::sparse )
        auto it = Sparse().find(_at);
        assert(it != Sparse().end());
        return it->second;
    }
}

template <class T>
void variable_container<T>::resize(size_t _new_size)
{
    if( m_Type == type::dense )
        Dense().resize(_new_size);
}

template <class T>
void variable_container<T>::insert(size_t _at, const T &_value)
{
    if( m_Type == type::common ) {
        Common() = _value;
    }
    else if( m_Type == type::dense ) {
        if( Dense().size() <= _at )
            Dense().resize(_at + 1);
        Dense()[_at] = _value;
    }
    else if( m_Type == type::sparse ) {
        auto r = Sparse().insert(typename sparse_type::value_type(_at, _value));
        if( !r.second )
            r.first->second = _value;
    }
}

template <class T>
void variable_container<T>::insert(size_t _at, T &&_value)
{
    if( m_Type == type::common ) {
        Common() = std::move(_value);
    }
    else if( m_Type == type::dense ) {
        if( Dense().size() <= _at )
            Dense().resize(_at + 1);
        Dense()[_at] = std::move(_value);
    }
    else if( m_Type == type::sparse ) {
        auto i = Sparse().find((unsigned)_at);
        if( i == std::end(Sparse()) )
            Sparse().insert(typename sparse_type::value_type((unsigned)_at, std::move(_value)));
        else
            i->second = std::move(_value);
    }
}

template <class T>
bool variable_container<T>::has(size_t _at) const noexcept
{
    if( m_Type == type::common )
        return true;
    else if( m_Type == type::dense )
        return _at < Dense().size();
    else // if( m_Type == type::sparse )
        return Sparse().contains(_at);
}

template <class T>
size_t variable_container<T>::size() const noexcept
{
    if( m_Type == type::common )
        return 1;
    else if( m_Type == type::dense )
        return Dense().size();
    else // if( m_Type == type::sparse )
        return Sparse().size();
}

template <class T>
bool variable_container<T>::empty() const noexcept
{
    return size() == 0;
}

template <class T>
bool variable_container<T>::is_contiguous() const noexcept
{
    if( m_Type == type::dense || m_Type == type::common )
        return true;

    auto &sparse = Sparse();
    
    for( size_t i = 0, e = size(); i != e; ++i )
        if( !sparse.contains(i) )
            return false;

    return true;
}

template <class T>
void variable_container<T>::compress_contiguous()
{
    if( m_Type != type::sparse )
        throw std::logic_error(
            "variable_container<T>::compress_contiguous was called for a non-sparse container");

    variable_container<T> new_dense(type::dense);

    size_t i = 0, e = size();
    auto &dense = new_dense.Dense();
    dense.reserve(e);

    auto &sparse = Sparse();
    for( ; i != e; ++i )
        dense.emplace_back(std::move(sparse.at(i)));

    *this = std::move(new_dense);
}

} // namespace nc::base
