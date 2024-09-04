// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreText/CTFont.h>
#include <CoreGraphics/CGFont.h>
#include <array>
#include <map>
#include <memory>
#include <cassert>
#include <ankerl/unordered_dense.h>
#include "FontExtras.h"
#include <Base/CFPtr.h>

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

inline CTFontRef FontCache::BaseFont() const noexcept
{
    return m_CTFonts[0].get();
}

inline CTFontRef FontCache::Font(unsigned _no) const noexcept
{
    assert(_no < m_CTFonts.size());
    return m_CTFonts[_no].get();
}

inline double FontCache::Size() const noexcept
{
    return m_FontInfo.Size();
}

inline double FontCache::Height() const noexcept
{
    return m_FontInfo.LineHeight();
}

inline double FontCache::Width() const noexcept
{
    return m_FontInfo.MonospaceWidth();
}

inline double FontCache::Ascent() const noexcept
{
    return m_FontInfo.Ascent();
}

inline double FontCache::Descent() const noexcept
{
    return m_FontInfo.Descent();
}

inline double FontCache::Leading() const noexcept
{
    return m_FontInfo.Leading();
}

} // namespace nc::utility
