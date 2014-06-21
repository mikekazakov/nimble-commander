#pragma once

#include <CoreText/CTFont.h>
#include <CoreGraphics/CGFont.h>

class FontCache
{
public:
    FontCache(CTFontRef _basic_font);
    ~FontCache();
    
    // consider using plain uint4 here for performance (?) need to check
    struct Pair
    {
        inline Pair():font(0),searched(0),glyph(0){};
        unsigned char font; // zero mean that basic font is just ok, other ones are the indeces of ctfallbacks/cgfallbacks
        unsigned char searched; // zero means that this glyph wasn't looked up yet. otherwise it's a space need for glyph to display (1 or 2)
        CGGlyph       glyph;
    }; // 4bytes total

    inline CTFontRef BaseCTFont() const {return m_CTFonts[0];}
    inline CTFontRef *CTFonts() const {return (CTFontRef *)m_CTFonts;}
    inline double Size()    const {return m_FontSize;}
    inline double Height()  const {return m_FontHeight;}
    inline double Width()   const {return m_FontWidth;}
    inline double Ascent()  const {return m_FontAscent;}
    inline double Descent() const {return m_FontDescent;}
    inline double Leading() const {return m_FontLeading;}
    
    Pair    Get(UniChar _c);
    
    static shared_ptr<FontCache> FontCacheFromFont(CTFontRef _basic_font);
    
private:
    CTFontRef   m_CTFonts[256]; // will anybody need more than 256 fallback fonts?
                                // fallbacks start from [1]. [0] is basefont
    Pair        m_Cache[65536];
    
    CFStringRef m_FontName;
    double      m_FontSize;
    double      m_FontHeight;
    double      m_FontWidth;
    double      m_FontAscent;
    double      m_FontDescent;
    double      m_FontLeading;
    
    FontCache(const FontCache&); // forbid
};

extern unsigned char g_WCWidthTableFixedMin1[65536];
