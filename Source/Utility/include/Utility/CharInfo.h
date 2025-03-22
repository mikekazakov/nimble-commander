// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

} // namespace nc::utility
