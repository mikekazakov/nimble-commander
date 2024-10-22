// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CTCache.h"
#include <Utility/FontExtras.h>
#include <algorithm>
#include <iostream>
#include <memory_resource>

namespace nc::term {

static constexpr bool IsBoxDrawingCharacter(char32_t _ch) noexcept
{
    return _ch >= 0x2500 && _ch <= 0x257F;
}

CTCache::CTCache(base::CFPtr<CTFontRef> _font, const ExtendedCharRegistry &_reg) : m_Reg(_reg)
{
    m_Fonts.push_back(std::move(_font));
    InitBasicLatinChars();

    const utility::FontGeometryInfo font_info(m_Fonts.front().get());

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
        const size_t len = CFStringGetSurrogatePairForLongCharacter(_code, buf) ? 2 : 1;
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
        CFDictionaryCreate(nullptr, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
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

    auto insert_full = [=, this] -> DisplayChar {
        m_Complexes.emplace_back(_line);
        return {.kind = Kind::Complex, .index = static_cast<uint32_t>(m_Complexes.size() - 1)};
    };

    CFArrayRef runs = CTLineGetGlyphRuns(_line);
    if( runs == nullptr )
        return {.kind = Kind::Empty, .index = 0};

    const long runs_count = CFArrayGetCount(runs);
    if( runs_count != 1 )
        return insert_full();

    CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0));
    if( run == nullptr )
        return {.kind = Kind::Empty, .index = 0};

    if( CTRunGetStatus(run) & kCTRunStatusHasNonIdentityMatrix )
        return insert_full();

    const long glyphs_count = CTRunGetGlyphCount(run);
    if( glyphs_count == 0 )
        return {.kind = Kind::Empty, .index = 0};
    if( glyphs_count > 1 )
        return insert_full();

    uint16_t glyphs[1] = {0};
    CTRunGetGlyphs(run, CFRangeMake(0, 1), glyphs);

    CFDictionaryRef run_attrs = CTRunGetAttributes(run);
    if( run_attrs == nullptr )
        return {.kind = Kind::Empty, .index = 0};

    CTFontRef font = static_cast<CTFontRef>(CFDictionaryGetValue(run_attrs, CFSTR("NSFont")));
    if( font == nullptr )
        return {.kind = Kind::Empty, .index = 0};

    const uint16_t font_idx = FindOrInsert(font);
    m_Singles.push_back({glyphs[0], font_idx});

    return {.kind = Kind::Single, .index = static_cast<uint32_t>(m_Singles.size() - 1)};
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

        // For a specific set of characters also ensure that antialiasing is turned off, otherwise frames look wrong
        const bool is_box = IsBoxDrawingCharacter(_code);
        if( is_box )
            CGContextSetShouldAntialias(_ctx, false);

        const uint16_t glyph = s.glyph;
        const CGPoint pos{0., 0.};
        CTFontDrawGlyphs(font, &glyph, &pos, 1, _ctx);

        if( is_box )
            CGContextSetShouldAntialias(_ctx, true);
    }
    else if( dc.kind == Kind::Complex ) {
        assert(dc.index < m_Complexes.size());
        CTLineRef ct_line = m_Complexes[dc.index].get();
        assert(ct_line);
        CTLineDraw(ct_line, _ctx);
    }
}

void CTCache::DrawCharacters(const char32_t *_codes, const CGPoint *_positions, size_t _count, CGContextRef _ctx)
{
    if( _count == 0 ) {
        return; // nothing to do
    }
    assert(_codes != nullptr);
    assert(_positions != nullptr);
    assert(_ctx != nullptr);

    if( _count == 1 ) {
        // for a single code it's faster to use a non-batched version
        CGContextSetTextPosition(_ctx, _positions[0].x, _positions[0].y);
        DrawCharacter(_codes[0], _ctx);
        return;
    }

    // Data to be fed into CTFontDrawGlyphs(..)
    struct IndexedSimple {
        uint16_t glyph;
        uint16_t font;
        uint32_t idx;
    };

    // Data to be fed into CTLineDraw(..)
    struct Complex {
        CTLineRef line;
        CGPoint pos;
    };

    // store the temp data on stack whether possible
    std::array<char, 16384> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
    std::pmr::vector<IndexedSimple> simple_glyphs(&mem_resource);
    std::pmr::vector<IndexedSimple> simple_box_glyphs(&mem_resource);
    std::pmr::vector<Complex> complex_glyphs(&mem_resource);

    // 1st - scan the input to look up for the according display chars and divide them into three categories
    for( size_t idx = 0; idx != _count; ++idx ) {
        const char32_t code = _codes[idx];
        const DisplayChar dc = GetChar(code);
        if( dc.kind == Kind::Single ) {
            const bool is_box = IsBoxDrawingCharacter(code);
            (is_box ? simple_box_glyphs : simple_glyphs)
                .push_back({m_Singles[dc.index].glyph, m_Singles[dc.index].font, static_cast<uint32_t>(idx)});
        }
        if( dc.kind == Kind::Complex ) {
            complex_glyphs.push_back({m_Complexes[dc.index].get(), _positions[idx]});
        }
    }

    // 2nd sort simple glyphs by their font number
    auto less_font = [](auto &_lhs, auto &_rhs) { return _lhs.font < _rhs.font; };
    std::ranges::sort(simple_glyphs, less_font);
    std::ranges::sort(simple_box_glyphs, less_font);

    // 3rd - draw normal simple glyphs, font by font
    std::pmr::vector<uint16_t> glyphs_to_ct(&mem_resource);
    std::pmr::vector<CGPoint> pos_to_ct(&mem_resource);
    auto flush = [&](CTFontRef _font) {
        assert(pos_to_ct.size() == glyphs_to_ct.size());
        if( !glyphs_to_ct.empty() ) {
            CGContextSetTextPosition(_ctx, 0., 0.);
            CTFontDrawGlyphs(_font, glyphs_to_ct.data(), pos_to_ct.data(), glyphs_to_ct.size(), _ctx);
            glyphs_to_ct.clear();
            pos_to_ct.clear();
        }
    };

    for( size_t idx = 0; idx != simple_glyphs.size(); idx++ ) {
        if( idx != 0 && simple_glyphs[idx - 1].font != simple_glyphs[idx].font ) {
            flush(m_Fonts[simple_glyphs[idx - 1].font].get());
        }
        glyphs_to_ct.push_back(simple_glyphs[idx].glyph);
        pos_to_ct.push_back(_positions[simple_glyphs[idx].idx]);
        pos_to_ct.back().y = -pos_to_ct.back().y; // wtf is with the Y-coordinate?
        if( idx + 1 == simple_glyphs.size() ) {
            flush(m_Fonts[simple_glyphs[idx].font].get());
        }
    }

    // 4th - now draw box simple glyphs, font by font
    if( !simple_box_glyphs.empty() ) {
        CGContextSetShouldAntialias(_ctx, false);
        for( size_t idx = 0; idx != simple_box_glyphs.size(); idx++ ) {
            if( idx != 0 && simple_box_glyphs[idx - 1].font != simple_box_glyphs[idx].font ) {
                flush(m_Fonts[simple_box_glyphs[idx - 1].font].get());
            }
            glyphs_to_ct.push_back(simple_box_glyphs[idx].glyph);
            pos_to_ct.push_back(_positions[simple_box_glyphs[idx].idx]);
            pos_to_ct.back().y = -pos_to_ct.back().y; // wtf is with the Y-coordinate?
            if( idx + 1 == simple_box_glyphs.size() ) {
                flush(m_Fonts[simple_box_glyphs[idx].font].get());
            }
        }
        CGContextSetShouldAntialias(_ctx, true);
    }

    // 5th - now draw the complex glyphs
    for( const auto &complex : complex_glyphs ) {
        CGContextSetTextPosition(_ctx, complex.pos.x, complex.pos.y);
        CTLineDraw(complex.line, _ctx);
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
    m_Fonts.emplace_back(_font);
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
    auto it =
        std::ranges::find_if(m_Caches, [&](auto &ptr) { return CFEqual(ptr.lock()->GetBaseFont(), _font.get()); });
    if( it != m_Caches.end() )
        return it->lock();

    // no luck - create a new one
    auto cache = std::make_shared<CTCache>(_font, m_Reg);
    m_Caches.emplace_back(cache);
    return cache;
}

} // namespace nc::term
