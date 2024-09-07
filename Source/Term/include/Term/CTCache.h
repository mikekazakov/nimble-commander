// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.

#include "ExtendedCharRegistry.h"
#include <CoreText/CoreText.h>
#include <Base/CFPtr.h>
#include <ankerl/unordered_dense.h>
#include <array>

namespace nc::term {

// NB! these classes are currently thread-agnostic and shouldn't be used concurrently

class CTCache
{
public:
    CTCache(base::CFPtr<CTFontRef> _font, const ExtendedCharRegistry &_reg);

    // Returns a base font for this cache, no refcnt changes is made
    CTFontRef GetBaseFont() const noexcept;

    // Size of the base font
    double Size() const noexcept;

    // Glyph height of the base font
    double Height() const noexcept;

    // Glyph height of the base font, rounded
    double Width() const noexcept;

    // Ascent of the base font
    double Ascent() const noexcept;

    // Descent of the base font
    double Descent() const noexcept;

    // Leading of the base font
    double Leading() const noexcept;

    // Draw a single character with semanantics following CTLineDraw.
    // Use CGContextSetTextPosition to set up a start position.
    // Leaves '_ctx' in unspecified state (?).
    void DrawCharacter(char32_t _code, CGContextRef _ctx);

    // Draws a batchs of characters with semanantics following CTLineDraw.
    // Sets coordinates automatically, _positions are relative to (0, 0).
    // Leaves '_ctx' in unspecified state (?).
    void DrawCharacters(const char32_t *_codes, const CGPoint *_positions, size_t _count, CGContextRef _ctx);

private:
    enum class Kind : int {
        Single = 0,  // A simple single glyph, stored in m_Singles
        Complex = 1, // A complext CTLine, stored in m_Complexes
        Empty = 2,   // Nothing to draw
    };

    struct Single {
        uint16_t glyph;
        uint16_t font;
    };

    struct DisplayChar {
        Kind kind;
        uint32_t index;
    };

    void InitBasicLatinChars();

    DisplayChar Internalize(CTLineRef _line);

    DisplayChar GetChar(char32_t _code) noexcept;

    CTLineRef Build(char32_t _code);

    uint16_t FindOrInsert(CTFontRef _font);

    const ExtendedCharRegistry &m_Reg;
    std::array<DisplayChar, 128> m_BasicLatinChars;                   // [0..127], contiguous
    ankerl::unordered_dense::map<char32_t, DisplayChar> m_OtherChars; // [128..inf], sparse

    std::vector<base::CFPtr<CTFontRef>> m_Fonts; // 0 - the base font
    std::vector<Single> m_Singles;
    std::vector<base::CFPtr<CTLineRef>> m_Complexes;
    double m_GeomSize;
    double m_GeomWidth;
    double m_GeomHeight;
    double m_GeomAscent;
    double m_GeomDescent;
    double m_GeomLeading;
};

class CTCacheRegistry
{
public:
    CTCacheRegistry(const ExtendedCharRegistry &_reg);

    // Either returns an existing cache which was made for this font or creates a new one, memories and return that.
    // The registry doesn't expand the lifetime of the caches - if all the users of a particular cache release their
    // references, it will be removed.
    std::shared_ptr<CTCache> CacheForFont(base::CFPtr<CTFontRef> _font);

private:
    const ExtendedCharRegistry &m_Reg;
    std::vector<std::weak_ptr<CTCache>> m_Caches;
    //    std::shared_ptr<CTCache>
};

} // namespace nc::term
