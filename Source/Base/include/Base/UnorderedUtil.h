// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <tuple>
#include <ankerl/unordered_dense.h>
#include <string_view>

namespace nc {

struct UnorderedStringHashEqual {
    using is_transparent = void;
    using is_avalanching = void;
    size_t operator()(std::string_view _str) const noexcept;
    bool operator()(std::string_view _lhs, std::string_view _rhs) const noexcept;
};

inline size_t UnorderedStringHashEqual::operator()(std::string_view _str) const noexcept
{
    return ankerl::unordered_dense::hash<std::string_view>{}(_str);
}

inline bool UnorderedStringHashEqual::operator()(std::string_view _lhs, std::string_view _rhs) const noexcept
{
    return _lhs == _rhs;
}

} // namespace nc
