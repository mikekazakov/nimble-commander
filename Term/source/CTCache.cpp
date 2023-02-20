// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CTCache.h"
#include <Utility/FontExtras.h>

namespace nc::term {

CTCache::CTCache(base::CFPtr<CTFontRef> _font, const ExtendedCharRegistry &_reg) : m_Reg(_reg)
{
    m_Fonts.push_back(std::move(_font));
    InitBasicLatinChars();

    utility::FontGeometryInfo font_info(m_Fonts.front().get());

    m_GeomSize = font_info.Size();
    m_GeomWidth = font_info.MonospaceWidth();
    m_GeomHeight = font_info.LineHeight();
    m_GeomAscent = font_info.Ascent();
    m_GeomDescent = font_info.Descent();
    m_GeomLeading = font_info.Leading();
}

void CTCache::InitBasicLatinChars()
{
    for( size_t c = 0; c < m_BasicLatinChars.size(); ++c ) {
        auto line = Build(static_cast<char32_t>(c));
        m_BasicLatinChars[c] = Internalize(line);
    }
}

CTFontRef CTCache::GetBaseFont() const noexcept
{
    assert(!m_Fonts.empty());
    return m_Fonts.front().get();
}

double CTCache::Size() const noexcept
{
    return m_GeomSize;
}

double CTCache::Height() const noexcept
{
    return m_GeomHeight;
}

double CTCache::Width() const noexcept
{
    return m_GeomWidth;
}

double CTCache::Ascent() const noexcept
{
    return m_GeomAscent;
}

double CTCache::Descent() const noexcept
{
    return m_GeomDescent;
}

double CTCache::Leading() const noexcept
{
    return m_GeomLeading;
}

CTCache::DisplayChar CTCache::GetChar(char32_t _code) noexcept
{
    if( static_cast<size_t>(_code) < m_BasicLatinChars.size() )
        return m_BasicLatinChars[static_cast<size_t>(_code)];

    if( auto it = m_OtherChars.find(_code); it != m_OtherChars.end() )
        return it->second;

    auto line = Build(_code);

    auto dc = Internalize(line);
    m_OtherChars.emplace(_code, dc);

    return dc;
}

CTLineRef CTCache::Build(char32_t _code)
{
    base::CFPtr<CFStringRef> str;
    if( ExtendedCharRegistry::IsBase(_code) ) {
        uint16_t buf[2];
        size_t len = CFStringGetSurrogatePairForLongCharacter(_code, buf) ? 2 : 1;
        str = base::CFPtr<CFStringRef>::adopt(CFStringCreateWithCharacters(nullptr, buf, len));
    }
    else {
        str = m_Reg.Decode(_code);
    }

    if( !str )
        return {};

    const void *keys[2] = {kCTFontAttributeName, kCTForegroundColorFromContextAttributeName};
    const void *values[2] = {m_Fonts.front().get(), kCFBooleanTrue};

    auto str_dict = base::CFPtr<CFDictionaryRef>::adopt(
        CFDictionaryCreate(NULL, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
    if( !str_dict )
        return {};

    auto str_attr =
        base::CFPtr<CFAttributedStringRef>::adopt(CFAttributedStringCreate(nullptr, str.get(), str_dict.get()));
    if( !str_attr )
        return {};

    return CTLineCreateWithAttributedString(str_attr.get());
}

CTCache::DisplayChar CTCache::Internalize(CTLineRef _line)
{
    assert(_line);

    auto insert_full = [=] -> DisplayChar {
        m_Complexes.push_back(base::CFPtr<CTLineRef>(_line));
        return {Kind::Complex, static_cast<uint32_t>(m_Complexes.size() - 1)};
    };

    CFArrayRef runs = static_cast<CFArrayRef>(CTLineGetGlyphRuns(_line));
    if( runs == nullptr )
        return {Kind::Empty, 0};

    const long runs_count = CFArrayGetCount(runs);
    if( runs_count != 1 )
        return insert_full();

    CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0));
    if( run == nullptr )
        return {Kind::Empty, 0};

    if( CTRunGetStatus(run) & kCTRunStatusHasNonIdentityMatrix )
        return insert_full();

    const long glyphs_count = CTRunGetGlyphCount(run);
    if( glyphs_count == 0 )
        return {Kind::Empty, 0};
    if( glyphs_count > 1 )
        return insert_full();

    uint16_t glyphs[1] = {0};
    CTRunGetGlyphs(run, CFRangeMake(0, 1), glyphs);

    CFDictionaryRef run_attrs = CTRunGetAttributes(run);
    if( run_attrs == nullptr )
        return {Kind::Empty, 0};

    CTFontRef font = static_cast<CTFontRef>(CFDictionaryGetValue(run_attrs, CFSTR("NSFont")));
    if( font == nullptr )
        return {Kind::Empty, 0};

    const uint16_t font_idx = FindOrInsert(font);
    m_Singles.push_back({glyphs[0], font_idx});

    return {Kind::Single, static_cast<uint32_t>(m_Singles.size() - 1)};
}

void CTCache::DrawCharacter(char32_t _code, CGContextRef _ctx)
{
    const DisplayChar dc = GetChar(_code);
    if( dc.kind == Kind::Single ) {
        assert(dc.index < m_Singles.size());
        const Single s = m_Singles[dc.index];
        assert(s.font < m_Fonts.size());
        CTFontRef font = m_Fonts[s.font].get();
        assert(font);

        uint16_t glyph = s.glyph;
        CGPoint pos{0., 0.};
        CTFontDrawGlyphs(font, &glyph, &pos, 1, _ctx);
    }
    else if( dc.kind == Kind::Complex ) {
        assert(dc.index < m_Complexes.size());
        CTLineRef ct_line = m_Complexes[dc.index].get();
        assert(ct_line);
        CTLineDraw(ct_line, _ctx);
    }
}

uint16_t CTCache::FindOrInsert(CTFontRef _font)
{
    assert(_font);
    for( size_t i = 0, e = m_Fonts.size(); i != e; ++i ) {
        if( CFEqual(_font, m_Fonts[i].get()) ) {
            return static_cast<uint16_t>(i);
        }
    }
    m_Fonts.push_back(base::CFPtr<CTFontRef>(_font));
    return static_cast<uint16_t>(m_Fonts.size() - 1);
}

CTCacheRegistry::CTCacheRegistry(const ExtendedCharRegistry &_reg) : m_Reg(_reg)
{
}

std::shared_ptr<CTCache> CTCacheRegistry::CacheForFont(base::CFPtr<CTFontRef> _font)
{
    // 1st pass - remove any outdated pointers, O(n)
    std::erase_if(m_Caches, [](auto &ptr) { return ptr.expired(); });

    // 2nd pass - try to find an existing cache, O(n)
    auto it = std::find_if(
        m_Caches.begin(), m_Caches.end(), [&](auto &ptr) { return CFEqual(ptr.lock()->GetBaseFont(), _font.get()); });
    if( it != m_Caches.end() )
        return it->lock();

    // no luck - create a new one
    auto cache = std::make_shared<CTCache>(_font, m_Reg);
    m_Caches.emplace_back(cache);
    return cache;
}

} // namespace nc::term
