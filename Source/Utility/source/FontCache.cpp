// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <CoreText/CoreText.h>
#include <Utility/FontCache.h>
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdlib>
#include <cwchar>
#include <memory.h>
#include <vector>

namespace nc::utility {

[[clang::no_destroy]] static std::vector<std::weak_ptr<FontCache>> g_Caches;

static bool IsLastResortFont(CTFontRef _font)
{
    CFStringRef family = CTFontCopyPostScriptName(_font);
    if( !family )
        return false;

    const bool is_resort = CFStringCompare(family, CFSTR("LastResort"), 0) == kCFCompareEqualTo;

    CFRelease(family);
    return is_resort;
}

static base::CFPtr<CTFontRef> CreateFallbackFontStraight(uint32_t _unicode, CTFontRef _basic_font)
{
    uint16_t chars[2];
    const auto str = [&] {
        if( _unicode < 0x10000 ) { // BMP
            chars[0] = static_cast<unsigned short>(_unicode);
            auto cf_str = CFStringCreateWithCharactersNoCopy(nullptr, chars, 1, kCFAllocatorNull);
            return base::CFPtr<CFStringRef>::adopt(cf_str);
        }
        else { // non-BMP
            chars[0] = static_cast<unsigned short>(0xD800 + ((_unicode - 0x010000) >> 10));
            chars[1] = static_cast<unsigned short>(0xDC00 + ((_unicode - 0x010000) & 0x3FF));
            auto cf_str = CFStringCreateWithCharactersNoCopy(nullptr, chars, 2, kCFAllocatorNull);
            return base::CFPtr<CFStringRef>::adopt(cf_str);
        }
    }();

    if( !str )
        return {};

    const auto range = CFRangeMake(0, 1);
    const auto font = CTFontCreateForString(_basic_font, str.get(), range);
    return base::CFPtr<CTFontRef>::adopt(font);
}

static base::CFPtr<CTFontRef> CreateFallbackFontHardway(uint32_t _unicode, CTFontRef _basic_font)
{
    static CFStringRef font_key = CFSTR("NSFont");
    static CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, 1000, 1000), nullptr);
    CTFontRef font = nullptr;
    CFStringRef str = nullptr;
    CFDictionaryRef str_dict = nullptr;
    CFAttributedStringRef str_attr = nullptr;
    CTFramesetterRef framesetter = nullptr;
    CTFrameRef frame = nullptr;
    CFArrayRef lines = nullptr;
    CTLineRef line = nullptr;
    CFArrayRef runs = nullptr;
    CTRunRef run = nullptr;
    CFDictionaryRef dict = nullptr;
    uint16_t chrs[2];

    if( _unicode < 0x10000 ) { // BMP
        chrs[0] = static_cast<uint16_t>(_unicode);
        str = CFStringCreateWithCharactersNoCopy(nullptr, chrs, 1, kCFAllocatorNull);
    }
    else { // non-BMP
        chrs[0] = static_cast<uint16_t>(0xD800 + ((_unicode - 0x010000) >> 10));
        chrs[1] = static_cast<uint16_t>(0xDC00 + ((_unicode - 0x010000) & 0x3FF));
        str = CFStringCreateWithCharactersNoCopy(nullptr, chrs, 2, kCFAllocatorNull);
    }

    if( str == nullptr )
        goto cleanup;

    static auto font_name_attribute = kCTFontNameAttribute;
    str_dict = CFDictionaryCreate(nullptr,
                                  reinterpret_cast<const void **>(&_basic_font),
                                  reinterpret_cast<const void **>(&font_name_attribute),
                                  1,
                                  &kCFTypeDictionaryKeyCallBacks,
                                  &kCFTypeDictionaryValueCallBacks);
    if( str_dict == nullptr )
        goto cleanup;

    str_attr = CFAttributedStringCreate(nullptr, str, str_dict);
    if( str_attr == nullptr )
        goto cleanup;

    framesetter = CTFramesetterCreateWithAttributedString(str_attr);
    if( framesetter == nullptr )
        goto cleanup;

    frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nullptr);
    if( frame == nullptr )
        goto cleanup;

    lines = CTFrameGetLines(frame);
    if( lines == nullptr || CFArrayGetCount(lines) == 0 )
        goto cleanup;

    line = static_cast<CTLineRef>(CFArrayGetValueAtIndex(lines, 0));
    if( line == nullptr )
        goto cleanup;

    runs = CTLineGetGlyphRuns(line);
    if( runs == nullptr || CFArrayGetCount(runs) == 0 )
        goto cleanup;

    run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0));
    if( run == nullptr )
        goto cleanup;

    dict = CTRunGetAttributes(run);
    if( dict == nullptr )
        goto cleanup;

    font = static_cast<CTFontRef>(CFDictionaryGetValue(dict, font_key));
    if( font )
        CFRetain(font);

cleanup:
    if( frame )
        CFRelease(frame);
    if( framesetter )
        CFRelease(framesetter);
    if( str_attr )
        CFRelease(str_attr);
    if( str_dict )
        CFRelease(str_dict);
    if( str )
        CFRelease(str);

    return base::CFPtr<CTFontRef>::adopt(font);
}

std::shared_ptr<FontCache> FontCache::FontCacheFromFont(CTFontRef _basic_font)
{
    const auto full_name = base::CFPtr<CFStringRef>::adopt(CTFontCopyFullName(_basic_font));
    const double font_size = CTFontGetSize(_basic_font);
    for( auto &i : g_Caches ) {
        auto font = i.lock();
        const bool same_name = CFStringCompare(font->m_FontName.get(), full_name.get(), 0) == kCFCompareEqualTo;
        const bool same_size = std::fabs(font->Size() - font_size) < 0.1;
        if( same_name && same_size ) {
            // just return already created font cache
            return font;
        }
    }

    auto font = std::make_shared<FontCache>(_basic_font);
    g_Caches.emplace_back(font);
    return font;
}

FontCache::FontCache(CTFontRef _basic_font) : m_FontInfo(_basic_font)
{
    static_assert(sizeof(Pair) == 4);
    m_FontName = decltype(m_FontName)::adopt(CTFontCopyFullName(_basic_font));

    m_CTFonts[0] = base::CFPtr<CTFontRef>(_basic_font);
    m_CacheBMP[0].searched = 1;
}

FontCache::~FontCache()
{
    std::erase_if(g_Caches, [](const auto &_t) { return _t.lock() == nullptr; });
}

FontCache::Pair FontCache::DoGetBMP(uint16_t _c)
{
    if( m_CacheBMP[_c].searched )
        return m_CacheBMP[_c];

    // currently assuming that we don't need to go hard-way fallback font searching for BMP
    // characters

    // unknown unichar - ask system about it
    CGGlyph g;
    bool r = CTFontGetGlyphsForCharacters(m_CTFonts[0].get(), &_c, &g, 1);
    if( r ) {
        m_CacheBMP[_c].searched = 1;
        m_CacheBMP[_c].glyph = g;
        return m_CacheBMP[_c];
    }
    else {
        // need to look up for fallback font
        auto ctfont = CreateFallbackFontStraight(_c, m_CTFonts[0].get());
        if( ctfont ) {
            r = CTFontGetGlyphsForCharacters(ctfont.get(), &_c, &g, 1);
            if( r ) // it should be true always, but for confidence...
            {
                // check if this font is new one, or we already have this one in dictionary
                for( size_t i = 1; i < m_CTFonts.size(); ++i ) {
                    if( m_CTFonts[i] ) {
                        if( CFEqual(m_CTFonts[i].get(),
                                    ctfont.get()) ) { // this is just the exactly one we need
                            m_CacheBMP[_c].font = static_cast<uint8_t>(i);
                            m_CacheBMP[_c].searched = 1;
                            m_CacheBMP[_c].glyph = g;
                            return m_CacheBMP[_c];
                        }
                    }
                    else {
                        // a new one
                        m_CTFonts[i] = ctfont;
                        m_CacheBMP[_c].font = static_cast<uint8_t>(i);
                        m_CacheBMP[_c].searched = 1;
                        m_CacheBMP[_c].glyph = g;
                        return m_CacheBMP[_c];
                    }
                }
                assert(0); // assume this will never overflow - we should never came here
                return {};
            }
            else { // something is very-very bad in the system - let this unichar be a null
                m_CacheBMP[_c].searched = 1;
                return m_CacheBMP[_c];
            }
        }
        else { // no luck
            m_CacheBMP[_c].searched = 1;
            return m_CacheBMP[_c];
        }
    }

    return {};
}

FontCache::Pair FontCache::DoGetNonBMP(uint32_t _c)
{
    const auto it = m_CacheNonBMP.find(_c);
    if( it != std::end(m_CacheNonBMP) )
        return it->second;

    // unknown unichar - ask system about it
    uint16_t utf16[2];
    utf16[0] = static_cast<uint16_t>(0xD800 + ((_c - 0x010000) >> 10));
    utf16[1] = static_cast<uint16_t>(0xDC00 + ((_c - 0x010000) & 0x3FF));

    CGGlyph g[2];
    bool r = CTFontGetGlyphsForCharacters(m_CTFonts[0].get(), utf16, g, 2);
    if( r ) { // glyph found in basic font
        Pair p;
        p.font = 0;
        p.searched = 1;
        p.glyph = g[0];
        m_CacheNonBMP.emplace(_c, p);
        return p;
    }
    else { // need to try fallback fonts
        if( auto font_straight = CreateFallbackFontStraight(_c, m_CTFonts[0].get()) ) {
            r = CTFontGetGlyphsForCharacters(font_straight.get(), utf16, g, 2);
            if( r ) {
                if( !IsLastResortFont(font_straight.get()) ) { // ok, use it
                    Pair p;
                    p.font = InsertFont(font_straight);
                    p.searched = 1;
                    p.glyph = g[0];
                    m_CacheNonBMP.emplace(_c, p);
                    return p;
                }
                else { // try hard way to extract font from CoreText-made layout
                    if( auto font_hard = CreateFallbackFontHardway(_c, m_CTFonts[0].get()) ) {
                        r = CTFontGetGlyphsForCharacters(font_hard.get(), utf16, g, 2);
                        if( r ) { // use this font
                            Pair p;
                            p.font = InsertFont(font_hard);
                            p.searched = 1;
                            p.glyph = g[0];
                            m_CacheNonBMP.emplace(_c, p);
                            return p;
                        }
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

unsigned char FontCache::InsertFont(base::CFPtr<CTFontRef> _font)
{
    for( size_t i = 1; i < m_CTFonts.size(); ++i )
        if( m_CTFonts[i] ) {
            if( CFEqual(m_CTFonts[i].get(), _font.get()) ) { // this is just the exactly one we need
                return static_cast<unsigned char>(i);
            }
        }
        else {
            // a new one
            m_CTFonts[i] = std::move(_font);
            return static_cast<unsigned char>(i);
        }
    return 0;
}

FontCache::Pair FontCache::Get(uint32_t _c) noexcept
{
    return _c < 0x10000 ? DoGetBMP(static_cast<uint16_t>(_c)) : DoGetNonBMP(_c);
}

} // namespace nc::utility
