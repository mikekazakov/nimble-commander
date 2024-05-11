// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <algorithm>
#include <memory>
#include <string>
#include <assert.h>
#include <stdio.h>
#include <string>
#include <string_view>
#include <vector>
#include <sys/stat.h>

template <typename T>
auto linear_generator(T _base, T _step)
{
    return [=, value = _base]() mutable {
        auto v = value;
        value += _step;
        return v;
    };
}

template <typename C, typename T>
size_t linear_find_or_insert(C &_c, const T &_v)
{
    auto b = std::begin(_c), e = std::end(_c);
    auto it = std::find(b, e, _v);
    if( it != e )
        return std::distance(b, it);

    _c.emplace_back(_v);
    return _c.size() - 1;
}

template <typename C>
std::shared_ptr<C> to_shared_ptr(C &&_object)
{
    return std::make_shared<C>(std::move(_object));
}

template <typename T>
auto at_scope_end(T _l)
{
    struct guard {
        guard(T &&_lock) : m_l(std::move(_lock)) {}

        guard(guard &&) = default;

        ~guard() noexcept
        {
            if( m_engaged )
                try {
                    m_l();
                } catch( ... ) {
                    fprintf(stderr, "exception thrown inside a at_scope_end() lambda!\n");
                }
        }

        bool engaded() const noexcept { return m_engaged; }

        void engage() noexcept { m_engaged = true; }

        void disengage() noexcept { m_engaged = false; }

    private:
        T m_l;
        bool m_engaged = true;
    };

    return guard(std::move(_l));
}

class upward_flag
{
    bool _state = false;

public:
    inline operator bool() const noexcept { return _state; };
    inline void toggle() noexcept { _state = true; };
};

class downward_flag
{
    bool _state = true;

public:
    inline operator bool() const noexcept { return _state; };
    inline void toggle() noexcept { _state = false; };
};

template <class InputIt>
bool all_equal(InputIt _first, InputIt _last)
{
    if( _first == _last )
        return true;
    const auto &v = *(_first++);
    while( _first != _last )
        if( *(_first++) != v )
            return false;
    return true;
}

template <class InputIt, class UnaryPredicate>
bool all_equal(InputIt _first, InputIt _last, UnaryPredicate _p)
{
    if( _first == _last )
        return true;
    const auto &v = _p(*(_first++));
    while( _first != _last )
        if( _p(*(_first++)) != v )
            return false;
    return true;
}

namespace nc::base {

[[nodiscard]] std::string_view Trim(std::string_view _str) noexcept;
[[nodiscard]] std::string_view Trim(std::string_view _str, char _c) noexcept;
[[nodiscard]] std::string_view TrimLeft(std::string_view _str) noexcept;
[[nodiscard]] std::string_view TrimLeft(std::string_view _str, char _c) noexcept;
[[nodiscard]] std::string_view TrimRight(std::string_view _str) noexcept;
[[nodiscard]] std::string_view TrimRight(std::string_view _str, char _c) noexcept;
[[nodiscard]] std::string ReplaceAll(std::string_view _source, char _what, std::string_view _with) noexcept;
[[nodiscard]] std::string ReplaceAll(std::string_view _source, std::string_view _what, std::string_view _with) noexcept;

[[nodiscard]] std::vector<std::string>
SplitByDelimiters(std::string_view _str, std::string_view _delims, bool _compress = true) noexcept;

[[nodiscard]] std::vector<std::string>
SplitByDelimiter(std::string_view _str, char _delim, bool _compress = true) noexcept;

} // namespace nc::base

constexpr bool operator==(const struct ::timespec &_lhs, const struct ::timespec &_rhs) noexcept
{
    return _lhs.tv_sec == _rhs.tv_sec && _lhs.tv_nsec == _rhs.tv_nsec;
}

constexpr bool operator!=(const struct ::timespec &_lhs, const struct ::timespec &_rhs) noexcept
{
    return !(_lhs == _rhs);
}
