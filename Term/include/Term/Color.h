// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <stdint.h>
#include <compare>

namespace nc::term {

// RTFM: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
//   0-  7: standard colors (as in ESC [ 30–37 m)
//   8- 15: high intensity colors (as in ESC [ 90–97 m)
//  16-231: 6 × 6 × 6 cube (216 colors): 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
// 232-255: grayscale from dark to light in 24 steps
struct Color {
    static constexpr uint8_t Black = 0;
    static constexpr uint8_t Red = 1;
    static constexpr uint8_t Green = 2;
    static constexpr uint8_t Yellow = 3;
    static constexpr uint8_t Blue = 4;
    static constexpr uint8_t Magenta = 5;
    static constexpr uint8_t Cyan = 6;
    static constexpr uint8_t White = 7;
    static constexpr uint8_t BrightBlack = 8;
    static constexpr uint8_t BrightRed = 9;
    static constexpr uint8_t BrightGreen = 10;
    static constexpr uint8_t BrightYellow = 11;
    static constexpr uint8_t BrightBlue = 12;
    static constexpr uint8_t BrightMagenta = 13;
    static constexpr uint8_t BrightCyan = 14;
    static constexpr uint8_t BrightWhite = 15;

    constexpr Color() noexcept = default;
    constexpr Color(uint8_t _c) noexcept;
    constexpr Color(uint8_t _r, uint8_t _g, uint8_t _b) noexcept;
    constexpr auto operator<=>(const Color &rhs) const noexcept = default;

    uint8_t c = Black;
};

inline constexpr Color::Color(uint8_t _c) noexcept : c(_c)
{
}

inline constexpr Color::Color(uint8_t /*_r*/, uint8_t /*_g*/, uint8_t /*_b*/) noexcept : c(BrightMagenta)
{
    // TODO: implement
}

} // namespace nc::term
