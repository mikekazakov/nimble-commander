// Copyright (C) 2018-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <utility>
#include <cstdint>

/**
 * This tribool is almost identical to boost::logic::tribool, with the expection of the size:
 * sizeof(nc::hbn::tribool) == 1, whiles sizeof(boost::logic::tribool) == 4.
 */

namespace nc::base {

class tribool;

struct indeterminate_type_t {
    constexpr bool operator()(tribool _v) const noexcept;
};
inline static const constexpr indeterminate_type_t indeterminate;

class tribool
{
public:
    constexpr tribool() noexcept;
    constexpr tribool(bool _value) noexcept;
    constexpr tribool(indeterminate_type_t /*unused*/) noexcept;

    constexpr explicit operator bool() const noexcept;

    enum class value_t : std::int8_t {
        false_value = 0,
        true_value = 1,
        indeterminate_value = 2
    };
    value_t value;
};

constexpr tribool::tribool() noexcept : value{value_t::false_value}
{
    static_assert(sizeof(tribool) == 1);
}

constexpr tribool::tribool(bool _value) noexcept : value{_value ? value_t::true_value : value_t::false_value}
{
}

constexpr tribool::tribool(indeterminate_type_t /*unused*/) noexcept : value{value_t::indeterminate_value}
{
}

constexpr tribool::operator bool() const noexcept
{
    return value == value_t::true_value;
}

constexpr tribool operator!(tribool _v) noexcept
{
    if( _v.value == tribool::value_t::true_value )
        return tribool{false};
    if( _v.value == tribool::value_t::false_value )
        return tribool{true};
    return _v;
}

constexpr tribool operator==(tribool _1, tribool _2) noexcept
{
    if( indeterminate(_1) || indeterminate(_2) )
        return indeterminate;
    return _1.value == _2.value;
}

constexpr tribool operator==(tribool _1, bool _2) noexcept
{
    return _1 == tribool{_2};
}

constexpr tribool operator==(bool _1, tribool _2) noexcept
{
    return tribool{_1} == _2;
}

constexpr tribool operator==(tribool _1, indeterminate_type_t _2) noexcept
{
    return _1 == tribool{_2};
}

constexpr tribool operator==(indeterminate_type_t _1, tribool _2) noexcept
{
    return tribool{_1} == _2;
}

constexpr tribool operator!=(tribool _1, tribool _2) noexcept
{
    return !(_1 == _2);
}

constexpr tribool operator!=(tribool _1, bool _2) noexcept
{
    return !(_1 == _2);
}

constexpr tribool operator!=(bool _1, tribool _2) noexcept
{
    return !(_1 == _2);
}

constexpr tribool operator!=(tribool _1, indeterminate_type_t _2) noexcept
{
    return !(_1 == _2);
}

constexpr tribool operator!=(indeterminate_type_t _1, tribool _2) noexcept
{
    return !(_1 == _2);
}

constexpr tribool operator&&(tribool _1, tribool _2) noexcept
{
    if( _1.value == tribool::value_t::false_value || _2.value == tribool::value_t::false_value )
        return tribool{false};
    if( _1.value == tribool::value_t::true_value && _2.value == tribool::value_t::true_value )
        return tribool{true};
    return tribool{indeterminate};
}

constexpr tribool operator&&(tribool _1, bool _2) noexcept
{
    return _1 && tribool{_2};
}

constexpr tribool operator&&(bool _1, tribool _2) noexcept
{
    return tribool{_1} && _2;
}

constexpr tribool operator&&(tribool _1, indeterminate_type_t _2) noexcept
{
    return _1 && tribool{_2};
}

constexpr tribool operator&&(indeterminate_type_t _1, tribool _2) noexcept
{
    return tribool{_1} && _2;
}

constexpr tribool operator||(tribool _1, tribool _2) noexcept
{
    if( _1.value == tribool::value_t::true_value || _2.value == tribool::value_t::true_value )
        return tribool{true};
    if( _1.value == tribool::value_t::false_value && _2.value == tribool::value_t::false_value )
        return tribool{false};
    return tribool{indeterminate};
}

constexpr tribool operator||(tribool _1, bool _2) noexcept
{
    return _1 || tribool{_2};
}

constexpr tribool operator||(bool _1, tribool _2) noexcept
{
    return tribool{_1} || _2;
}

constexpr tribool operator||(tribool _1, indeterminate_type_t _2) noexcept
{
    return _1 || tribool{_2};
}

constexpr tribool operator||(indeterminate_type_t _1, tribool _2) noexcept
{
    return tribool{_1} || _2;
}

constexpr bool indeterminate_type_t::operator()(tribool _v) const noexcept
{
    return _v.value == tribool::value_t::indeterminate_value;
}

} // namespace nc::base

namespace std {

inline void swap(nc::base::tribool &_lhs, nc::base::tribool &_rhs) noexcept
{
    std::swap(_lhs.value, _rhs.value);
}

template <>
struct hash<nc::base::tribool> {
    using argument_type = nc::base::tribool;
    using result_type = size_t;
    result_type operator()(const argument_type &_p) const { return hash<int>()(static_cast<int>(_p.value)); }
};

} // namespace std
