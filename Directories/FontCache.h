#pragma once

#include <CoreText/CTFont.h>
#include <CoreGraphics/CGFont.h>

class FontCache
{
public:
    // consider using plain uint4 here for performance (?) need to check
    struct Pair
    {
        inline Pair():font(0),searched(0),glyph(0){};
        unsigned char font; // zero mean that basic font is just ok, other ones are the indeces of ctfallbacks/cgfallbacks
        unsigned char searched; // zero means that this glyph wasn't looked up yet. otherwise it's a space need for glyph to display (1 or 2)
        CGGlyph       glyph;
    }; // 4bytes total

    FontCache(CTFontRef _basic_font);
    Pair           cache[65536];
    CTFontRef      ctbasefont;
    CGFontRef      cgbasefont;
    CTFontRef      ctfallbacks[256]; // will anybody need more than 256 fallback fonts?
                                     // fallbacks start from [1]. [0] is basefont
    CGFontRef      cgfallbacks[256]; // -""-. owned by FontCache
    
    Pair    Get(UniChar _c);
private:

//    static FontCache* Allocate(CTFontRef _font);
//    static void       Delete(FontCache *);
//    static
};

extern unsigned char g_WCWidthTableFixedMin1[65536];
