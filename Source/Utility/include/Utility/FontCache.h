// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreText/CTFont.h>
#include <array>
#include <memory>
#include <ankerl/unordered_dense.h>
#include <Base/CFPtr.h>
#include "FontExtras.h"

namespace nc::utility {

// TODO: migrate to Term
class FontCache
{
public:
    struct Pair {
        uint8_t font = 0;     // zero mean that basic font is just ok, other ones are the indices of ctfallbacks
        uint8_t searched = 0; // zero means that this glyph wasn't looked up yet
        uint16_t glyph = 0;   // zero glyphs should be ignored - that signal some king of failure
    }; // 4bytes total

    FontCache(CTFontRef _basic_font);
    FontCache(const FontCache &) = delete;
    ~FontCache();

    CTFontRef BaseFont() const noexcept;
    CTFontRef Font(unsigned _no) const noexcept;
    double Size() const noexcept;
    double Height() const noexcept;
    double Width() const noexcept;
    double Ascent() const noexcept;
    double Descent() const noexcept;
    double Leading() const noexcept;
    Pair Get(uint32_t _c) noexcept;

    static std::shared_ptr<FontCache> FontCacheFromFont(CTFontRef _basic_font);

private:
    Pair DoGetBMP(uint16_t _c);
    Pair DoGetNonBMP(uint32_t _c);
    unsigned char InsertFont(base::CFPtr<CTFontRef> _font);

    // will anybody need more than 256 fallback fonts?
    // fallbacks start from [1]. [0] is basefont
    std::array<base::CFPtr<CTFontRef>, 256> m_CTFonts;
    std::array<Pair, 65536> m_CacheBMP;
    ankerl::unordered_dense::map<uint32_t, Pair> m_CacheNonBMP;
    base::CFPtr<CFStringRef> m_FontName;
    FontGeometryInfo m_FontInfo;
};

} // namespace nc::utility
