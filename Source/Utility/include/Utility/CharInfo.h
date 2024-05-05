// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>

namespace nc::utility {

class CharInfo
{
public:
    static bool IsUnicodeCombiningCharacter(uint32_t _a) noexcept;
    static bool CanCharBeTheoreticallyComposed(uint32_t _c) noexcept;
    static unsigned char WCWidthMin1(uint32_t _c) noexcept;
    static void BuildPossibleCompositionEvidenceTable();

    static constexpr bool IsVariationSelector(uint32_t _c) noexcept;

private:
    static const uint32_t g_PossibleCompositionEvidence[2048];
    static const uint64_t g_WCWidthTableIsFullSize[1024];
};

inline bool CharInfo::IsUnicodeCombiningCharacter(uint32_t _a) noexcept
{
    return (_a >= 0x0300 && _a <= 0x036F) || (_a >= 0x1DC0 && _a <= 0x1DFF) || (_a >= 0x20D0 && _a <= 0x20FF) ||
           (_a >= 0xFE20 && _a <= 0xFE2F);
}

inline bool CharInfo::CanCharBeTheoreticallyComposed(uint32_t _c) noexcept
{
    if( _c >= 0x10000 )
        return false;
    return (g_PossibleCompositionEvidence[_c / 32] >> (_c % 32)) & 1;
}

inline unsigned char CharInfo::WCWidthMin1(uint32_t _c) noexcept
{
    if( _c < 0x10000 ) {
        return ((g_WCWidthTableIsFullSize[_c / 64] >> (_c % 64)) & 1) ? 2 : 1;
    }
    else {
        // https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2020/p1868r2.html
        const bool dw = (_c >= 0x1F100 && _c <= 0x1F1FF) || // Enclosed Alphanumeric Supplement
                        (_c >= 0x1F300 && _c <= 0x1F64F) || // Miscellaneous Symbols and Pictographs
                        (_c >= 0x1F900 && _c <= 0x1F9FF) || // Supplemental Symbols and Pictographs
                        (_c >= 0x20000 && _c <= 0x2FFFD) || // Supplementary Ideographic Plane
                        (_c >= 0x30000 && _c <= 0x3FFFD);   // Tertiary Ideographic Plane
        return dw ? 2 : 1;
    }
}

} // namespace nc::utility
