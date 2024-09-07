// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <cassert>
#include <vector>
#include <variant>
#include <ankerl/unordered_dense.h>

namespace nc::base {

namespace detail {

struct variable_container_base {
    enum class type : unsigned char {
        dense = 0,
        sparse = 1,
        common = 2
    };
};

} // namespace detail

// variable_container is a hybrid container, which can take one of 3 forms - a common value container, a dense container
// and a sparse container. It's useful when characteristics of data can dratically change in run-time and not known in
// advance. variable_container is not compatible with all idioms of STL containers and should be used with care.
template <class T = int>
class variable_container
{
public:
    using value_type = T;
    using reference = T &;
    using const_reference = const T &;
    using type = detail::variable_container_base::type;

    // Creates a container with a specified type.
    // A common value container will implicitly create the default value.
    variable_container(type _type = type::common);

    // Creates a container with a common value copied from the parameter.
    variable_container(const T &_value);

    // Creates a container with a common value moved from the parameter.
    variable_container(T &&_value);

    // Returns the current container's type.
    constexpr type mode() const noexcept;

    // Reverts the container to an empty state with a specified type.
    void reset(type _type);

    // Returns a reference to an element at the specified index and throws if it doesn't exist.
    // For the common mode returns the common value.
    // For other modes uses .at() of vector<> and unordered_map<>.
    T &at(size_t _at);

    // Returns a reference to an element at the specified index and throws if it doesn't exist.
    // For the common mode returns the common value.
    // For other modes uses .at() of vector<> and unordered_flat_map<>.
    const T &at(size_t _at) const;

    // Returns a reference to an existing element at the specified index.
    // For the common mode returns the common value.
    // For the dense mode uses vector<>::operator[].
    // For the sparse mode uses unordered_flat_map<>::find (precondition: the element must exist).
    T &operator[](size_t _at) noexcept;

    // Returns a reference to an existing element at the specified index.
    // For the common mode returns the common value.
    // For the dense mode uses vector<>::operator[].
    // For the sparse mode uses unordered_flat_map<>::find (precondition: the element must exist).
    const T &operator[](size_t _at) const noexcept;

    // Returns the amount of elements inside the container.
    // For common mode always returns 1.
    // For other modes return the size of a corresponding container.
    size_t size() const noexcept;

    // returns size() == 0;
    bool empty() const noexcept;

    // Resizes the container to a new size.
    // Can be used only with Dense mode, ignored otherwise.
    void resize(size_t _new_size);

    // Inserts the value into the container at the specified index.
    // If mode is Dense and _at is above the current size the container will resize accordingly.
    // If mode is Common the _at index will be ignored and the common value will be set with _value.
    void insert(size_t _at, const T &_value);

    // Inserts the value into the container at the specified index.
    // If mode is Dense and _at is above the current size the container will resize accordingly.
    // If mode is Common the _at index will be ignored and the common value will be set with _value.
    void insert(size_t _at, T &&_value);

    // Checks at the container has an element at the specified index.
    // For the common mode always returns true.
    // For the sparse mode checks for presence of this item in the unordered map.
    // For the dense mode checks the vector bounds.
    bool has(size_t _at) const noexcept;

    // Checks if the container has no gaps in the seqence of used indices.
    // Returns true if:
    //  - the type is common or dense
    //  - the type is sparse and the map contains all keys in [0, size)
    bool is_contiguous() const noexcept;

    // Transforms a sparse container with contiguous elements into a dense container.
    // Will throw a logic_error if any element is missing (i.e., the container is non contiguous).
    // If container isn't of a sparse type - will throw a logic_error.
    void compress_contiguous();

private:
    using common_type = value_type;
    using sparse_type = ankerl::unordered_dense::map<size_t, T>;
    using dense_type = std::vector<T>;
    using StorageT = std::variant<dense_type, sparse_type, common_type>;

    common_type &Common() noexcept;
    const common_type &Common() const noexcept;
    sparse_type &Sparse() noexcept;
    const sparse_type &Sparse() const noexcept;
    dense_type &Dense() noexcept;
    const dense_type &Dense() const noexcept;

    StorageT m_Storage;
};

template <class T>
variable_container<T>::variable_container(type _type)
    : m_Storage(_type == type::common   ? StorageT{std::in_place_type<common_type>}
                : _type == type::sparse ? StorageT{std::in_place_type<sparse_type>}
                                        : StorageT{std::in_place_type<dense_type>})
{
}

template <class T>
variable_container<T>::variable_container(const T &_value) : m_Storage{_value}
{
}

template <class T>
variable_container<T>::variable_container(T &&_value) : m_Storage{std::move(_value)}
{
}

template <class T>
constexpr typename variable_container<T>::type variable_container<T>::mode() const noexcept
{
    return static_cast<type>(m_Storage.index());
}

template <class T>
void variable_container<T>::reset(type _type)
{
    *this = variable_container<T>(_type);
}

template <class T>
typename variable_container<T>::common_type &variable_container<T>::Common() noexcept
{
    assert(std::holds_alternative<common_type>(m_Storage));
    return *std::get_if<common_type>(&m_Storage);
}

template <class T>
const typename variable_container<T>::common_type &variable_container<T>::Common() const noexcept
{
    assert(std::holds_alternative<common_type>(m_Storage));
    return *std::get_if<common_type>(&m_Storage);
}

template <class T>
typename variable_container<T>::sparse_type &variable_container<T>::Sparse() noexcept
{
    assert(std::holds_alternative<sparse_type>(m_Storage));
    return *std::get_if<sparse_type>(&m_Storage);
}

template <class T>
const typename variable_container<T>::sparse_type &variable_container<T>::Sparse() const noexcept
{
    assert(std::holds_alternative<sparse_type>(m_Storage));
    return *std::get_if<sparse_type>(&m_Storage);
}

template <class T>
typename variable_container<T>::dense_type &variable_container<T>::Dense() noexcept
{
    assert(std::holds_alternative<dense_type>(m_Storage));
    return *std::get_if<dense_type>(&m_Storage);
}

template <class T>
const typename variable_container<T>::dense_type &variable_container<T>::Dense() const noexcept
{
    assert(std::holds_alternative<dense_type>(m_Storage));
    return *std::get_if<dense_type>(&m_Storage);
}

template <class T>
T &variable_container<T>::at(size_t _at)
{
    switch( mode() ) {
        case type::common: {
            return Common();
        }
        case type::dense: {
            return Dense().at(_at);
        }
        case type::sparse: {
            return Sparse().at(_at);
        }
    }
}

template <class T>
T &variable_container<T>::operator[](size_t _at) noexcept
{
    switch( mode() ) {
        case type::common: {
            return Common();
        }
        case type::dense: {
            assert(_at < Dense().size());
            return Dense()[_at];
        }
        case type::sparse: {
            auto it = Sparse().find(_at);
            assert(it != Sparse().end());
            return it->second;
        }
    }
}

template <class T>
const T &variable_container<T>::at(size_t _at) const
{
    switch( mode() ) {
        case type::common: {
            return Common();
        }
        case type::dense: {
            return Dense().at(_at);
        }
        case type::sparse: {
            return Sparse().at(_at);
        }
    }
}

template <class T>
const T &variable_container<T>::operator[](size_t _at) const noexcept
{
    switch( mode() ) {
        case type::common: {
            return Common();
        }
        case type::dense: {
            assert(_at < Dense().size());
            return Dense()[_at];
        }
        case type::sparse: {
            auto it = Sparse().find(_at);
            assert(it != Sparse().end());
            return it->second;
        }
    }
}

template <class T>
void variable_container<T>::resize(size_t _new_size)
{
    if( mode() == type::dense )
        Dense().resize(_new_size);
}

template <class T>
void variable_container<T>::insert(size_t _at, const T &_value)
{
    switch( mode() ) {
        case type::common: {
            Common() = _value;
            break;
        }
        case type::dense: {
            dense_type &dense = Dense();
            if( dense.size() <= _at )
                dense.resize(_at + 1);
            dense[_at] = _value;
            break;
        }
        case type::sparse: {
            sparse_type &sparse = Sparse();
            auto i = sparse.find(_at);
            if( i == sparse.end() )
                sparse.emplace(_at, _value);
            else
                i->second = std::move(_value);
            break;
        }
    }
}

template <class T>
void variable_container<T>::insert(size_t _at, T &&_value)
{
    switch( mode() ) {
        case type::common: {
            Common() = std::move(_value);
            break;
        }
        case type::dense: {
            dense_type &dense = Dense();
            if( dense.size() <= _at )
                dense.resize(_at + 1);
            dense[_at] = std::move(_value);
            break;
        }
        case type::sparse: {
            sparse_type &sparse = Sparse();
            auto i = sparse.find(_at);
            if( i == sparse.end() )
                sparse.emplace(_at, std::move(_value));
            else
                i->second = std::move(_value);
            break;
        }
    }
}

template <class T>
bool variable_container<T>::has(size_t _at) const noexcept
{
    switch( mode() ) {
        case type::common:
            return true;
        case type::dense:
            return _at < Dense().size();
        case type::sparse:
            return Sparse().contains(_at);
    }
}

template <class T>
size_t variable_container<T>::size() const noexcept
{
    switch( mode() ) {
        case type::common:
            return 1;
        case type::dense:
            return Dense().size();
        case type::sparse:
            return Sparse().size();
    }
}

template <class T>
bool variable_container<T>::empty() const noexcept
{
    return size() == 0;
}

template <class T>
bool variable_container<T>::is_contiguous() const noexcept
{
    if( mode() == type::dense || mode() == type::common )
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
    if( mode() != type::sparse )
        throw std::logic_error("variable_container<T>::compress_contiguous was called for a non-sparse container");

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
