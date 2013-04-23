#pragma once

#include <CoreText/CTFont.h>
#include <CoreGraphics/CGFont.h>

class FontCacheManager;

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

    Pair           cache[65536];
    CTFontRef      ctbasefont;
    CGFontRef      cgbasefont;
    CTFontRef      ctfallbacks[256]; // will anybody need more than 256 fallback fonts?
                                     // fallbacks start from [1]. [0] is basefont
    CGFontRef      cgfallbacks[256]; // -""-. owned by FontCache
    
    Pair    Get(UniChar _c);
private:
    friend class FontCacheManager;
    FontCache(CTFontRef _basic_font);
    FontCache(const FontCache&); // forbid
};

class FontCacheManager
{
public:
    static FontCacheManager* Instance();
    
    void CreateFontCache(CFStringRef _font_name); // should be called once by The Application class
    FontCache* Get();
    
    // here will be functions to change font name etc. later.
    
private:
    FontCacheManager();
    FontCacheManager(const FontCacheManager&); // forbid
    FontCache *m_FontCache;
};

extern unsigned char g_WCWidthTableFixedMin1[65536];
