// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <CoreText/CoreText.h>
#include <stdlib.h>
#include <memory.h>
#include <assert.h>
#include <wchar.h>
#include <math.h>
#include <vector>
#include <Utility/FontCache.h>

namespace nc::utility {

static std::vector<std::weak_ptr<FontCache>> g_Caches;

static bool IsLastResortFont(CTFontRef _font)
{
    CFStringRef family = (CFStringRef)CTFontCopyPostScriptName(_font);
    if(!family)
        return false;
    
    bool is_resort = CFStringCompare(family, CFSTR ("LastResort"), 0) == kCFCompareEqualTo;
    
    CFRelease(family);
    return is_resort;
}

static CTFontRef GetFallbackFontStraight(uint32_t _unicode, CTFontRef _basic_font)
{
    CFStringRef str = NULL;

    if(_unicode < 0x10000) { // BMP
        uint16_t chr = _unicode;
        str = CFStringCreateWithCharactersNoCopy(0, &chr, 1, kCFAllocatorNull);
    } else { // non-BMP
        uint16_t nbmp[2];
        nbmp[0] = 0xD800 + ((_unicode - 0x010000) >> 10);
        nbmp[1] = 0xDC00 + ((_unicode - 0x010000) & 0x3FF);
        str = CFStringCreateWithCharactersNoCopy(0, nbmp, 2, kCFAllocatorNull);
    }
    
    if(str == NULL)
        return NULL;

    CTFontRef font = CTFontCreateForString(_basic_font, str, CFRangeMake(0, 1));
    
    CFRelease(str);
    return font;
}

static CTFontRef GetFallbackFontHardway(uint32_t _unicode, CTFontRef _basic_font)
{
    static CFStringRef font_key = CFSTR("NSFont");
    static CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, 1000, 1000), NULL);
    CTFontRef font = NULL;
    CFStringRef str = NULL;
    CFDictionaryRef str_dict = NULL;
    CFAttributedStringRef str_attr = NULL;
    CTFramesetterRef framesetter = NULL;
    CTFrameRef frame = NULL;
    CFArrayRef lines = NULL;
    CTLineRef line = NULL;
    CFArrayRef runs = NULL;
    CTRunRef run = NULL;
    CFDictionaryRef dict = NULL;
    uint16_t chrs[2];

    if(_unicode < 0x10000) { // BMP
        chrs[0] = _unicode;
        str = CFStringCreateWithCharactersNoCopy(0, chrs, 1, kCFAllocatorNull);
    } else { // non-BMP
        chrs[0] = 0xD800 + ((_unicode - 0x010000) >> 10);
        chrs[1] = 0xDC00 + ((_unicode - 0x010000) & 0x3FF);
        str = CFStringCreateWithCharactersNoCopy(0, chrs, 2, kCFAllocatorNull);
    }
    
    if(str == NULL)
        goto cleanup;
    
    str_dict = CFDictionaryCreate(NULL,
                                  (const void **)&_basic_font,
                                  (const void **)&kCTFontNameAttribute,
                                  1,
                                  &kCFTypeDictionaryKeyCallBacks,
                                  &kCFTypeDictionaryValueCallBacks);
    if(str_dict == NULL)
        goto cleanup;

    str_attr = CFAttributedStringCreate(NULL, str, str_dict);
    if(str_attr == NULL)
        goto cleanup;
    
    framesetter = CTFramesetterCreateWithAttributedString(str_attr);
    if(framesetter == NULL)
        goto cleanup;

    frame = CTFramesetterCreateFrame( framesetter, CFRangeMake(0, 0), path, NULL);
    if(frame == NULL)
        goto cleanup;
    
    lines = CTFrameGetLines(frame);
    if(lines == NULL || CFArrayGetCount(lines) == 0)
        goto cleanup;
    
    line = (CTLineRef)CFArrayGetValueAtIndex(lines, 0);
    if(line == NULL)
        goto cleanup;
    
    runs = (CFArrayRef) CTLineGetGlyphRuns(line);
    if(runs == NULL || CFArrayGetCount(runs) == 0)
        goto cleanup;
    
    run = (CTRunRef) CFArrayGetValueAtIndex(runs, 0);
    if(run == NULL)
        goto cleanup;
    
    dict = CTRunGetAttributes( run );
    if(dict == NULL)
        goto cleanup;

    font = (CTFontRef)CFDictionaryGetValue(dict, font_key);
    if(font)
        CFRetain(font);
    
cleanup:
    if(frame)
        CFRelease(frame);
    if(framesetter)
        CFRelease(framesetter);
    if(str_attr)
        CFRelease(str_attr);
    if(str_dict)
        CFRelease(str_dict);
    if(str)
        CFRelease(str);
    return font;
}


std::shared_ptr<FontCache> FontCache::FontCacheFromFont(CTFontRef _basic_font)
{
    CFStringRef full_name = CTFontCopyFullName(_basic_font);
    double font_size = CTFontGetSize(_basic_font);
    for(auto &i:g_Caches)
    {
        auto font = i.lock();
        if(!CFStringCompare(font->m_FontName, full_name, 0) && fabs(font->Size()-font_size) < 0.1)
        {
            // just return already created font cache
            CFRelease(full_name);
            return font;
        }
    }
    
    CFRelease(full_name);
    auto font = std::make_shared<FontCache>(_basic_font);
    g_Caches.emplace_back(font);
    return font;
}

FontCache::FontCache(CTFontRef _basic_font):
    m_FontInfo(_basic_font)
{
    static_assert(sizeof(Pair) == 4, "");
    m_CTFonts.fill(nullptr);
    m_FontName = CTFontCopyFullName(_basic_font);
    
    CFRetain(_basic_font);    
    m_CTFonts[0] = _basic_font;
    m_CacheBMP[0].searched = 1;
}

FontCache::~FontCache()
{
    CFRelease(m_FontName);
    
    for(auto i:m_CTFonts)
        if(i!=0)
            CFRelease(i);
    
    g_Caches.erase(remove_if(begin(g_Caches),
                             end(g_Caches),
                             [](auto _t) {
                                 return _t.lock() == nullptr;
                             }),
                   end(g_Caches)
                   );
}

FontCache::Pair FontCache::DoGetBMP(uint16_t _c)
{
    if(m_CacheBMP[_c].searched)
        return m_CacheBMP[_c];
    
    // currently assuming that we don't need to go hard-way fallback font searching for BMP characters
    
    // unknown unichar - ask system about it
    CGGlyph g;
    bool r = CTFontGetGlyphsForCharacters(m_CTFonts[0], &_c, &g, 1);
    if(r)
    {
        m_CacheBMP[_c].searched = 1;
        m_CacheBMP[_c].glyph = g;
        return m_CacheBMP[_c];
    }
    else
    {
        // need to look up for fallback font
        CTFontRef ctfont = GetFallbackFontStraight(_c, m_CTFonts[0]);
        if(ctfont != 0)
        {
            r = CTFontGetGlyphsForCharacters(ctfont, &_c, &g, 1);
            if(r == true) // it should be true always, but for confidence...
            {
                // check if this font is new one, or we already have this one in dictionary
                for(int i = 1; i < m_CTFonts.size(); ++i)
                {
                    if( m_CTFonts[i] != 0 )
                    {
                        if( CFEqual(m_CTFonts[i], ctfont) )
                        { // this is just the exactly one we need
                            CFRelease(ctfont);
                            m_CacheBMP[_c].font = i;
                            m_CacheBMP[_c].searched = 1;
                            m_CacheBMP[_c].glyph = g;
                            return m_CacheBMP[_c];
                        }
                    }
                    else
                    {
                        // a new one
                        m_CTFonts[i] = ctfont;
                        
                        m_CacheBMP[_c].font = i;
                        m_CacheBMP[_c].searched = 1;
                        m_CacheBMP[_c].glyph = g;
                        return m_CacheBMP[_c];
                    }
                }
                assert(0); // assume this will never overflow - we should never came here
                return FontCache::Pair();
            }
            else
            { // something is very-very bad in the system - let this unichar be a null
                CFRelease(ctfont);
                m_CacheBMP[_c].searched = 1;
                return m_CacheBMP[_c];
            }
        }
        else
        { // no luck
            m_CacheBMP[_c].searched = 1;
            return m_CacheBMP[_c];
        }
    }
    
    return FontCache::Pair();
}

FontCache::Pair FontCache::DoGetNonBMP(uint32_t _c)
{
    auto it = m_CacheNonBMP.find(_c);
    if(it != end(m_CacheNonBMP))
        return it->second;
    
    // unknown unichar - ask system about it
    uint16_t utf16[2];
    utf16[0] = 0xD800 + ((_c - 0x010000) >> 10);
    utf16[1] = 0xDC00 + ((_c - 0x010000) & 0x3FF);
    
    CGGlyph g[2];
    bool r = CTFontGetGlyphsForCharacters(m_CTFonts[0], utf16, g, 2);
    if(r)
    { // glyph found in basic font
        Pair p;
        p.font = 0;
        p.searched = 1;
        p.glyph = g[0];
        m_CacheNonBMP.emplace(_c, p);
        return p;
    }
    else
    { // need to try fallback fonts
        if(CTFontRef font_straight = GetFallbackFontStraight(_c, m_CTFonts[0])) {
            r = CTFontGetGlyphsForCharacters(font_straight, utf16, g, 2);
            if(r) {
                if( !IsLastResortFont(font_straight) ) { // ok, use it
                    Pair p;
                    p.font = InsertFont(font_straight);
                    p.searched = 1;
                    p.glyph = g[0];
                    m_CacheNonBMP.emplace(_c, p);
                    return p;
                }
                else { // try hard way to extract font from CoreText-made layout
                    if(CTFontRef font_hard = GetFallbackFontHardway(_c, m_CTFonts[0])) {
                        r = CTFontGetGlyphsForCharacters(font_hard, utf16, g, 2);
                        if(r) { // use this font
                            Pair p;
                            p.font = InsertFont(font_hard);
                            p.searched = 1;
                            p.glyph = g[0];
                            m_CacheNonBMP.emplace(_c, p);
                            CFRelease(font_straight);
                            return p;
                        }
                        CFRelease(font_hard);
                    }
                    // back to straight fallback
                    Pair p;
                    p.font = InsertFont(font_straight);
                    p.searched = 1;
                    p.glyph = g[0];
                    m_CacheNonBMP.emplace(_c, p);
                    return p;
                }
            }
            CFRelease(font_straight);
        }
        
        // no luck
        Pair p;
        p.font = 0;
        p.searched = 1;
        p.glyph = 0;
        m_CacheNonBMP.emplace(_c, p);
        return p;
    }
}

unsigned char FontCache::InsertFont(CTFontRef _font)
{
    for(int i = 1; i < m_CTFonts.size(); ++i)
        if( m_CTFonts[i] != 0 ) {
            if( CFEqual(m_CTFonts[i], _font) ) { // this is just the exactly one we need
                CFRelease(_font);
                return i;
            }
        }
        else {
            // a new one
            m_CTFonts[i] = _font;
            return i;
        }
    CFRelease(_font);
    return 0;
}

FontCache::Pair FontCache::Get(uint32_t _c)
{
    return _c < 0x10000 ? DoGetBMP(_c) : DoGetNonBMP(_c);
}

}
