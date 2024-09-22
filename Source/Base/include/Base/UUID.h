// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <array>
#include <cstdint>
#include <compare>
#include <string>
#include <string_view>
#include <optional>

namespace nc::base {

class UUID
{
public:
    UUID() noexcept;
    std::string ToString() const noexcept;
    size_t Hash() const noexcept;
    static UUID Generate() noexcept;
    static std::optional<UUID> FromString(std::string_view _str) noexcept;
    constexpr bool operator==(const UUID &) const noexcept = default;

private:
    std::array<uint8_t, 16> m_Data;
};

} // namespace nc::base

template <>
struct std::hash<nc::base::UUID> {
    size_t operator()(const nc::base::UUID &u) const noexcept;
};
