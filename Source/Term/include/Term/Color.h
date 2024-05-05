// Copyright (C) 2022-2023 Michael Kazakov. Subject to GNU General Public License version 3.
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

inline constexpr Color::Color(uint8_t _r, uint8_t _g, uint8_t _b) noexcept
{
    if( _r == _g && _r == _b ) {
        // quantize 255 values into 24 bands: [232..255]
        constexpr uint8_t tbl[256] = {
            232, 232, 232, 232, 232, 232, 232, 232, 232, 232, 232, // [000..010]
            233, 233, 233, 233, 233, 233, 233, 233, 233, 233, 233, // [011..021]
            234, 234, 234, 234, 234, 234, 234, 234, 234, 234,      // [022..031]
            235, 235, 235, 235, 235, 235, 235, 235, 235, 235, 235, // [032..042]
            236, 236, 236, 236, 236, 236, 236, 236, 236, 236, 236, // [043..053]
            237, 237, 237, 237, 237, 237, 237, 237, 237, 237,      // [054..063]
            238, 238, 238, 238, 238, 238, 238, 238, 238, 238, 238, // [064..074]
            239, 239, 239, 239, 239, 239, 239, 239, 239, 239, 239, // [075..085]
            240, 240, 240, 240, 240, 240, 240, 240, 240, 240,      // [086..095]
            241, 241, 241, 241, 241, 241, 241, 241, 241, 241, 241, // [096..106]
            242, 242, 242, 242, 242, 242, 242, 242, 242, 242, 242, // [107..117]
            243, 243, 243, 243, 243, 243, 243, 243, 243, 243,      // [118..127]
            244, 244, 244, 244, 244, 244, 244, 244, 244, 244, 244, // [128..138]
            245, 245, 245, 245, 245, 245, 245, 245, 245, 245, 245, // [139..149]
            246, 246, 246, 246, 246, 246, 246, 246, 246, 246,      // [150..159]
            247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, // [160..170]
            248, 248, 248, 248, 248, 248, 248, 248, 248, 248, 248, // [171..181]
            249, 249, 249, 249, 249, 249, 249, 249, 249, 249,      // [182..191]
            250, 250, 250, 250, 250, 250, 250, 250, 250, 250, 250, // [192..202]
            251, 251, 251, 251, 251, 251, 251, 251, 251, 251, 251, // [203..213]
            252, 252, 252, 252, 252, 252, 252, 252, 252, 252,      // [214..221]
            253, 253, 253, 253, 253, 253, 253, 253, 253, 253, 253, // [222..232]
            254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, // [233..243]
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255,      // [244..255]
        };
        c = tbl[_r];
    }
    else {
        // quantize 255 values into 6 bands: [16..231]
        const uint8_t r = _r / 43;
        const uint8_t g = _g / 43;
        const uint8_t b = _b / 43;
        c = 16 + 36 * r + 6 * g + b;
    }
}

} // namespace nc::term
