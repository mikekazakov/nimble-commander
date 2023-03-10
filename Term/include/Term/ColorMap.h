// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <CoreGraphics/CoreGraphics.h>
#include <Habanero/CFPtr.h>
#include <array>

namespace nc::term {

class ColorMap
{
public:
    enum class Special
    {
        Foreground = 0,
        BoldForeground = 1,
        Background = 2,
        Selection = 3,
        Cursor = 4
    };

    ColorMap();

    ~ColorMap();

    void SetSpecialColor(Special _color_type, NSColor *_color);

    // _color_idx must be in [0..15]
    void SetANSIColor(uint8_t _color_idx, NSColor *_color);

    CGColorRef GetSpecialColor(Special _color_type) noexcept;

    // Provides a 8-bit color.
    // The Base ANSI colors [0..15] are settable, while [16..255] are fixed.
    // Returns a non-owned reference.
    CGColorRef GetCGColor(uint8_t _color_idx) noexcept;

    // Same as GetCGColor, but the colors have an Alpha component less than 1.
    // Returns a non-owned reference
    CGColorRef GetFaintCGColor(uint8_t _color_idx) noexcept;

private:
    std::array<base::CFPtr<CGColorRef>, 16> m_ANSI;
    std::array<base::CFPtr<CGColorRef>, 16> m_FaintANSI;
    std::array<base::CFPtr<CGColorRef>, 5> m_Special;
};

} // namespace nc::term
