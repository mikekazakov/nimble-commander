// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreText/CTFont.h>
#include <CoreGraphics/CGFont.h>
#include <array>
#include <map>
#include <memory>
#include "FontExtras.h"

namespace nc::utility {

class FontCache
{
public:
    FontCache(CTFontRef _basic_font);
    ~FontCache();
    
    struct Pair
    {
        uint8_t     font = 0;       // zero mean that basic font is just ok, other ones are the indeces of ctfallbacks
        uint8_t     searched = 0;   // zero means that this glyph wasn't looked up yet
        uint16_t    glyph = 0;      // zero glyphs should be ignored - that signal some king of failure
    }; // 4bytes total

    inline CTFontRef BaseFont() const {return m_CTFonts[0];}
    inline CTFontRef Font(int _no) const { return m_CTFonts[_no]; }
    
    inline double Size()    const {return m_FontInfo.Size();}
    inline double Height()  const {return m_FontInfo.LineHeight();}
    inline double Width()   const {return m_FontInfo.MonospaceWidth();}
    inline double Ascent()  const {return m_FontInfo.Ascent();}
    inline double Descent() const {return m_FontInfo.Descent();}
    inline double Leading() const {return m_FontInfo.Leading();}
    
    Pair    Get(uint32_t _c);
    
    static std::shared_ptr<FontCache> FontCacheFromFont(CTFontRef _basic_font);
    
private:
    Pair DoGetBMP(uint16_t _c);
    Pair DoGetNonBMP(uint32_t _c);
    unsigned char InsertFont(CTFontRef _font);
    
    std::array<CTFontRef, 256> m_CTFonts;    // will anybody need more than 256 fallback fonts?
                                             // fallbacks start from [1]. [0] is basefont

    std::array<Pair, 65536> m_CacheBMP;
    // TODO: consider mutex locking here
    std::map<uint32_t, Pair> m_CacheNonBMP;
    
    CFStringRef m_FontName;
    FontGeometryInfo m_FontInfo;
    FontCache(const FontCache&); // forbid
};

}
