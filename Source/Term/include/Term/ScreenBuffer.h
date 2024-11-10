// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <vector>
#include <memory>
#include <string>
#include <span>

#include "Color.h"
#include "ExtendedCharRegistry.h"

namespace nc::term {

struct ScreenPoint {
    int x = 0;
    int y = 0;
    inline ScreenPoint() noexcept {};
    inline ScreenPoint(int _x, int _y) noexcept : x(_x), y(_y) {};
    inline bool operator>(const ScreenPoint &_r) const noexcept { return (y > _r.y) || (y == _r.y && x > _r.x); }
    inline bool operator>=(const ScreenPoint &_r) const noexcept { return (y > _r.y) || (y == _r.y && x >= _r.x); }
    inline bool operator<(const ScreenPoint &_r) const noexcept { return !(*this >= _r); }
    inline bool operator<=(const ScreenPoint &_r) const noexcept { return !(*this > _r); }
    inline bool operator==(const ScreenPoint &_r) const noexcept { return y == _r.y && x == _r.x; }
    inline bool operator!=(const ScreenPoint &_r) const noexcept { return y != _r.y || x != _r.x; }
};

class ScreenBuffer
{
public:
    struct Space {
        char32_t l;       // base or 'extended' UTF32 character
        Color foreground; // 8-bit color, meaningful when customfg==true
        Color background; // 8-bit color, meaningful when custombg==true
        bool customfg : 1;
        bool custombg : 1;
        bool faint : 1;
        bool underline : 1;
        bool crossed : 1;
        bool reverse : 1;
        bool bold : 1;
        bool italic : 1;
        bool invisible : 1;
        bool blink : 1;

        constexpr bool HaveSameAttributes(const Space &_rhs) const noexcept;
    }; // 8 bytes per screen space

    struct Snapshot {
        Snapshot();
        Snapshot(unsigned _w, unsigned _h);
        unsigned width;
        unsigned height;
        std::unique_ptr<Space[]> chars;
    };

    struct DumpOptions {
        static constexpr int Default = 0;
        static constexpr int BreakLines = 1 << 0;
        static constexpr int ReportMultiCellGlyphs = 1 << 2;
    };

    static const unsigned short MultiCellGlyph = 0xFFFE;

    ScreenBuffer(unsigned _width,
                 unsigned _height,
                 ExtendedCharRegistry &_reg = ExtendedCharRegistry::SharedInstance());

    unsigned Width() const;
    unsigned Height() const;
    unsigned BackScreenLines() const;

    // negative _line_number means backscreen, zero and positive - current screen
    // backscreen: [-BackScreenLines(), -1]
    // -BackScreenLines() is the oldest backscreen line
    // -1 is the last (most recent) backscreen line
    // return an iterator pair [i,e)
    // on invalid input parameters return [nullptr,nullptr)
    std::span<const Space> LineFromNo(int _line_number) const noexcept;
    std::span<Space> LineFromNo(int _line_number) noexcept;

    // Returns a value at the specified column (x) of the specified line (y).
    // Line number can be negative, same as with LineFromNo().
    // Throws an exception on invalid position.
    Space At(int x, int y) const;

    void ResizeScreen(unsigned _new_sx, unsigned _new_sy, bool _merge_with_backscreen);

    void FeedBackscreen(std::span<const Space> _with_spaces, bool _wrapped);

    bool LineWrapped(int _line_number) const;
    void SetLineWrapped(int _line_number, bool _wrapped);

    Space EraseChar() const;
    void SetEraseChar(Space _ch);
    static Space DefaultEraseChar() noexcept;

    /**
     * [1st, 2nd) lines range.
     * lines should have any non-zero symbol, including space (32).
     * if screen is absolutely clean it will return nullopt
     */
    std::optional<std::pair<int, int>> OccupiedOnScreenLines() const;

    std::vector<uint16_t> DumpUnicodeString(ScreenPoint _begin, ScreenPoint _end) const;

    using LayedOutUTF16Dump = std::pair<std::vector<uint16_t>, std::vector<ScreenPoint>>;
    LayedOutUTF16Dump DumpUTF16StringWithLayout(ScreenPoint _begin, ScreenPoint _end) const;

    // use for diagnose and test purposes only
    std::string DumpScreenAsANSI() const;
    std::string DumpScreenAsANSIBreaked() const;
    std::u32string DumpScreenAsUTF32(int _options = DumpOptions::Default) const;
    void LoadScreenFromANSI(std::string_view _dump);
    std::string DumpBackScreenAsANSI() const;

    Snapshot MakeSnapshot() const;
    void RevertToSnapshot(const Snapshot &_snapshot);

    static unsigned OccupiedChars(std::span<const Space> _line) noexcept;
    static unsigned OccupiedChars(const Space *_begin, const Space *_end) noexcept;

    // Returns 'true' if the range contains and non-null characters
    static bool HasOccupiedChars(const Space *_begin, const Space *_end) noexcept;

    unsigned OccupiedChars(int _line_no) const;
    bool HasOccupiedChars(int _line_no) const;

    std::vector<std::vector<Space>> ComposeContinuousLines(int _from,
                                                           int _to) const; // [_from, _to), _from is less than _to

private:
    struct LineMeta {
        unsigned start_index = 0;
        unsigned line_length = 0;
        bool is_wrapped = false;
    };

    LineMeta *MetaFromLineNo(int _line_number);
    const LineMeta *MetaFromLineNo(int _line_number) const;

    static void
    FixupOnScreenLinesIndeces(std::vector<LineMeta>::iterator _i, std::vector<LineMeta>::iterator _e, unsigned _width);
    static std::unique_ptr<Space[]> ProduceRectangularSpaces(unsigned _width, unsigned _height);
    static std::unique_ptr<Space[]> ProduceRectangularSpaces(unsigned _width, unsigned _height, Space _initial_char);
    static std::vector<std::tuple<std::vector<Space>, bool>>
    DecomposeContinuousLines(const std::vector<std::vector<Space>> &_src,
                             unsigned _width); // <spaces, is wrapped>

    unsigned m_Width = 0;  // onscreen and backscreen width
    unsigned m_Height = 0; // onscreen height, backscreen has arbitrary height
    const ExtendedCharRegistry &m_Registry;
    std::vector<LineMeta> m_OnScreenLines;
    std::vector<LineMeta> m_BackScreenLines;
    std::unique_ptr<Space[]> m_OnScreenSpaces; // rebuilt on screeen size change
    std::vector<Space> m_BackScreenSpaces;     // will be growing

    Space m_EraseChar = DefaultEraseChar();
};

constexpr bool ScreenBuffer::Space::HaveSameAttributes(const Space &_rhs) const noexcept
{
    uint64_t mask = 0x3FFFFFF00000000ULL;
    uint64_t lhs = *static_cast<const uint64_t *>(static_cast<const void *>(this));
    uint64_t rhs = *static_cast<const uint64_t *>(static_cast<const void *>(&_rhs));
    return (lhs & mask) == (rhs & mask);
}

} // namespace nc::term
