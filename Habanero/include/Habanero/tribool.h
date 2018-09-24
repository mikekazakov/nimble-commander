#pragma once

#include <utility>
#include <cstdint>

/**
 * This tribool is almost identical to boost::logic::tribool, with the expection of the size:
 * sizeof(nc::hbn::tribool) == 1, whiles sizeof(boost::logic::tribool) == 4.
 */

namespace nc::hbn {

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
    constexpr tribool(indeterminate_type_t) noexcept;    
    
    constexpr explicit operator bool() const noexcept;
    
    enum class value_t : std::int8_t {
        false_value = 0,
        true_value = 1,
        indeterminate_value = 2
    };
    value_t value;
};
    
inline constexpr tribool::tribool() noexcept :
    value{value_t::false_value}
{
    static_assert( sizeof(tribool) == 1 );
}
    
inline constexpr tribool::tribool(bool _value) noexcept :
    value{_value ? value_t::true_value : value_t::false_value}
{        
}
    
inline constexpr tribool::tribool(indeterminate_type_t) noexcept :
    value{value_t::indeterminate_value}
{
}

inline constexpr tribool::operator bool() const noexcept
{
    return value == value_t::true_value ? true : false;
}

inline constexpr tribool operator!(tribool _v) noexcept
{
    if( _v.value == tribool::value_t::true_value )
        return tribool{false};
    if( _v.value == tribool::value_t::false_value )
        return tribool{true};
    return _v;
}    

inline constexpr tribool operator==(tribool _1, tribool _2) noexcept
{
    if( indeterminate(_1) || indeterminate(_2) )
        return indeterminate;
    return _1.value == _2.value;
}

inline constexpr tribool operator==(tribool _1, bool _2) noexcept
{
    return _1 == tribool{_2};
}

inline constexpr tribool operator==(bool _1, tribool _2) noexcept
{
    return tribool{_1} == _2;
}

inline constexpr tribool operator==(tribool _1, indeterminate_type_t _2) noexcept
{
    return _1 == tribool{_2};
}

inline constexpr tribool operator==(indeterminate_type_t _1, tribool _2) noexcept
{
    return tribool{_1} == _2;
}
    
inline constexpr tribool operator!=(tribool _1, tribool _2) noexcept
{
    return !(_1 == _2);
}

inline constexpr tribool operator!=(tribool _1, bool _2) noexcept
{
    return !(_1 == _2);
}

inline constexpr tribool operator!=(bool _1, tribool _2) noexcept
{
    return !(_1 == _2);
}

inline constexpr tribool operator!=(tribool _1, indeterminate_type_t _2) noexcept
{
    return !(_1 == _2);
}

inline constexpr tribool operator!=(indeterminate_type_t _1, tribool _2) noexcept
{
    return !(_1 == _2);
}

inline constexpr tribool operator&&(tribool _1, tribool _2) noexcept
{
    if( _1.value == tribool::value_t::false_value || _2.value == tribool::value_t::false_value )
        return tribool{false};
    if( _1.value == tribool::value_t::true_value && _2.value == tribool::value_t::true_value )
        return tribool{true};
    return tribool{indeterminate};
}

inline constexpr tribool operator&&(tribool _1, bool _2) noexcept
{
    return _1 && tribool{_2};
}

inline constexpr tribool operator&&(bool _1, tribool _2) noexcept
{
    return tribool{_1} && _2;
}

inline constexpr tribool operator&&(tribool _1, indeterminate_type_t _2) noexcept
{
    return _1 && tribool{_2};
}

inline constexpr tribool operator&&(indeterminate_type_t _1, tribool _2) noexcept
{
    return tribool{_1} && _2;
}
    
inline constexpr tribool operator||(tribool _1, tribool _2) noexcept
{
    if( _1.value == tribool::value_t::true_value || _2.value == tribool::value_t::true_value )
        return tribool{true};
    if( _1.value == tribool::value_t::false_value && _2.value == tribool::value_t::false_value )
        return tribool{false};
    return tribool{indeterminate};
}
    
inline constexpr tribool operator||(tribool _1, bool _2) noexcept
{
    return _1 || tribool{_2};
}

inline constexpr tribool operator||(bool _1, tribool _2) noexcept
{
    return tribool{_1} || _2;
}

inline constexpr tribool operator||(tribool _1, indeterminate_type_t _2) noexcept
{
    return _1 || tribool{_2};
}

inline constexpr tribool operator||(indeterminate_type_t _1, tribool _2) noexcept
{
    return tribool{_1} || _2;
}
    
inline constexpr bool indeterminate_type_t::operator()(tribool _v) const noexcept
{
    return _v.value == tribool::value_t::indeterminate_value;
}

}

namespace std {

inline void swap( nc::hbn::tribool &_lhs, nc::hbn::tribool &_rhs ) noexcept
{
    std::swap(_lhs.value, _rhs.value);
}

template <>
struct hash< nc::hbn::tribool >
{
    using argument_type = nc::hbn::tribool; 
    using result_type = size_t; 
    result_type operator()(const argument_type& _p) const
    {
        return hash<int>()( static_cast<int>(_p.value) );
    }
};
    
}
