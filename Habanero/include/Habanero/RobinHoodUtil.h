// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <robin_hood.h>
#include <string_view>

namespace nc {

struct RHTransparentStringHashEqual {
    using is_transparent = void;
    size_t operator()(std::string_view str) const noexcept;
    bool operator()(std::string_view lhs, std::string_view rhs) const noexcept;
};

inline size_t RHTransparentStringHashEqual::operator()(std::string_view str) const noexcept
{
    return robin_hood::hash_bytes(str.data(), str.size());
}

inline bool RHTransparentStringHashEqual::operator()(std::string_view lhs,
                                                     std::string_view rhs) const noexcept
{
    return lhs == rhs;
}

} // namespace nc
