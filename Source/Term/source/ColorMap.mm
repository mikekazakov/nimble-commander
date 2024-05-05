// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ColorMap.h"
#include <Utility/HexadecimalColor.h>

namespace nc::term {

static constexpr double g_FaintColorAlpha = 0.6;

static const std::array<CGColorRef, 256> &BuiltInColors() noexcept
{
    static const std::array<CGColorRef, 256> colors = [] {
        std::array<CGColorRef, 256> colors;
        colors[0] = CGColorCreateCopy([NSColor colorWithHexString:"#000000"].CGColor);
        colors[1] = CGColorCreateCopy([NSColor colorWithHexString:"#990000"].CGColor);
        colors[2] = CGColorCreateCopy([NSColor colorWithHexString:"#00A600"].CGColor);
        colors[3] = CGColorCreateCopy([NSColor colorWithHexString:"#999900"].CGColor);
        colors[4] = CGColorCreateCopy([NSColor colorWithHexString:"#0000B2"].CGColor);
        colors[5] = CGColorCreateCopy([NSColor colorWithHexString:"#B200B2"].CGColor);
        colors[6] = CGColorCreateCopy([NSColor colorWithHexString:"#00A6B2"].CGColor);
        colors[7] = CGColorCreateCopy([NSColor colorWithHexString:"#BFBFBF"].CGColor);
        colors[8] = CGColorCreateCopy([NSColor colorWithHexString:"#666666"].CGColor);
        colors[9] = CGColorCreateCopy([NSColor colorWithHexString:"#E50000"].CGColor);
        colors[10] = CGColorCreateCopy([NSColor colorWithHexString:"#00D900"].CGColor);
        colors[11] = CGColorCreateCopy([NSColor colorWithHexString:"#E5E500"].CGColor);
        colors[12] = CGColorCreateCopy([NSColor colorWithHexString:"#0000FF"].CGColor);
        colors[13] = CGColorCreateCopy([NSColor colorWithHexString:"#E500E5"].CGColor);
        colors[14] = CGColorCreateCopy([NSColor colorWithHexString:"#00E5E5"].CGColor);
        colors[15] = CGColorCreateCopy([NSColor colorWithHexString:"#E5E5E5"].CGColor);
        for( int i = 16; i < 256; ++i ) {
            if( i >= 232 ) {
                const int v = i - 232;                          // [0, 23]
                const double dv = static_cast<double>(v) / 27.; // [0, 0.85]
                const double dv1 = dv + 0.05;                   // [0.05, 0.90]
                colors[i] = CGColorCreateCopy([NSColor colorWithWhite:dv1 alpha:1.].CGColor);
            }
            else {
                const int b = (i - 16) % 6;
                const int g = ((i - 16) / 6) % 6;
                const int r = (i - 16) / 36;
                colors[i] = CGColorCreateCopy([NSColor colorWithCalibratedRed:static_cast<double>(r) / 5.
                                                                        green:static_cast<double>(g) / 5.
                                                                         blue:static_cast<double>(b) / 5.
                                                                        alpha:1.]
                                                  .CGColor);
            }
        }
        return colors;
    }();
    return colors;
}

static const std::array<CGColorRef, 256> &BuiltInFaintColors() noexcept
{
    static const std::array<CGColorRef, 256> faint_colors = [] {
        const std::array<CGColorRef, 256> &colors = BuiltInColors();
        std::array<CGColorRef, 256> faint_colors;
        for( int i = 0; i < 256; ++i )
            faint_colors[i] = CGColorCreateCopyWithAlpha(colors[i], g_FaintColorAlpha);
        return faint_colors;
    }();
    return faint_colors;
}

ColorMap::ColorMap()
{
    const auto &colors = BuiltInColors();
    m_Special[static_cast<size_t>(Special::Foreground)] = base::CFPtr<CGColorRef>(colors[7]);
    m_Special[static_cast<size_t>(Special::BoldForeground)] = base::CFPtr<CGColorRef>(colors[15]);
    m_Special[static_cast<size_t>(Special::Background)] = base::CFPtr<CGColorRef>(colors[0]);
    m_Special[static_cast<size_t>(Special::Selection)] = base::CFPtr<CGColorRef>(colors[15]);
    m_Special[static_cast<size_t>(Special::Cursor)] = base::CFPtr<CGColorRef>(colors[8]);
}

ColorMap::~ColorMap() = default;

CGColorRef ColorMap::GetColor(uint8_t _color) noexcept
{
    if( _color < 16 && m_ANSI[_color] )
        return m_ANSI[_color].get();
    else
        return BuiltInColors()[_color];
}

CGColorRef ColorMap::GetFaintColor(uint8_t _color) noexcept
{
    if( _color < 16 && m_FaintANSI[_color] )
        return m_FaintANSI[_color].get();
    else
        return BuiltInFaintColors()[_color];
}

void ColorMap::SetANSIColor(uint8_t _color_idx, NSColor *_color)
{
    assert(_color != nil);
    assert(_color_idx < 16);
    m_ANSI[_color_idx] = base::CFPtr<CGColorRef>::adopt(CGColorCreateCopy(_color.CGColor));
    m_FaintANSI[_color_idx] =
        base::CFPtr<CGColorRef>::adopt(CGColorCreateCopyWithAlpha(m_ANSI[_color_idx].get(), g_FaintColorAlpha));
}

void ColorMap::SetSpecialColor(Special _color_type, NSColor *_color)
{
    assert(static_cast<size_t>(_color_type) < m_Special.size());
    assert(_color != nil);
    m_Special[static_cast<size_t>(_color_type)] = base::CFPtr<CGColorRef>::adopt(CGColorCreateCopy(_color.CGColor));
}

CGColorRef ColorMap::GetSpecialColor(Special _color_type) noexcept
{
    assert(static_cast<size_t>(_color_type) < m_Special.size());
    return m_Special[static_cast<size_t>(_color_type)].get();
}

} // namespace nc::term
