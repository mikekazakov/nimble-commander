#pragma once

#include <CoreText/CTFont.h>
#include <CoreGraphics/CGFont.h>

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
    
    inline double Size()    const {return m_FontSize;}
    inline double Height()  const {return m_FontHeight;}
    inline double Width()   const {return m_FontWidth;}
    inline double Ascent()  const {return m_FontAscent;}
    inline double Descent() const {return m_FontDescent;}
    inline double Leading() const {return m_FontLeading;}
    
    Pair    Get(uint32_t _c);
    
    static shared_ptr<FontCache> FontCacheFromFont(CTFontRef _basic_font);
    
private:
    Pair DoGetBMP(uint16_t _c);
    Pair DoGetNonBMP(uint32_t _c);
    unsigned char InsertFont(CTFontRef _font);
    
    array<CTFontRef, 256> m_CTFonts;    // will anybody need more than 256 fallback fonts?
                                        // fallbacks start from [1]. [0] is basefont

    array<Pair, 65536> m_CacheBMP;
    // TODO: consider mutex locking here
    map<uint32_t, Pair> m_CacheNonBMP;
    
    CFStringRef m_FontName;
    double      m_FontSize;
    double      m_FontHeight;
    double      m_FontWidth;
    double      m_FontAscent;
    double      m_FontDescent;
    double      m_FontLeading;
    
    FontCache(const FontCache&); // forbid
};

unsigned char WCWidthMin1(uint32_t _unicode);
extern unsigned char g_WCWidthTableFixedMin1[65536];
