// Copyright (C) 2015-2026 Michael Kazakov. Subject to GNU General Public License version 3.
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
    ScreenPoint() noexcept = default;
    ScreenPoint(int _x, int _y) noexcept : x(_x), y(_y) {};
    bool operator>(const ScreenPoint &_r) const noexcept { return (y > _r.y) || (y == _r.y && x > _r.x); }
    bool operator>=(const ScreenPoint &_r) const noexcept { return (y > _r.y) || (y == _r.y && x >= _r.x); }
    bool operator<(const ScreenPoint &_r) const noexcept { return !(*this >= _r); }
    bool operator<=(const ScreenPoint &_r) const noexcept { return !(*this > _r); }
    bool operator==(const ScreenPoint &_r) const noexcept { return y == _r.y && x == _r.x; }
    bool operator!=(const ScreenPoint &_r) const noexcept { return y != _r.y || x != _r.x; }
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

        [[nodiscard]] constexpr bool HaveSameAttributes(const Space &_rhs) const noexcept;
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

    [[nodiscard]] unsigned Width() const;
    [[nodiscard]] unsigned Height() const;
    [[nodiscard]] unsigned BackScreenLines() const;

    // negative _line_number means backscreen, zero and positive - current screen
    // backscreen: [-BackScreenLines(), -1]
    // -BackScreenLines() is the oldest backscreen line
    // -1 is the last (most recent) backscreen line
    // return an iterator pair [i,e)
    // on invalid input parameters return [nullptr,nullptr)
    [[nodiscard]] std::span<const Space> LineFromNo(int _line_number) const noexcept;
    std::span<Space> LineFromNo(int _line_number) noexcept;

    // Returns a value at the specified column (x) of the specified line (y).
    // Line number can be negative, same as with LineFromNo().
    // Throws an exception on invalid position.
    [[nodiscard]] Space At(int x, int y) const;

    void ResizeScreen(unsigned _new_sx, unsigned _new_sy, bool _merge_with_backscreen);

    void FeedBackscreen(std::span<const Space> _with_spaces, bool _wrapped);

    [[nodiscard]] bool LineWrapped(int _line_number) const;
    void SetLineWrapped(int _line_number, bool _wrapped);

    [[nodiscard]] Space EraseChar() const;
    void SetEraseChar(Space _ch);
    static Space DefaultEraseChar() noexcept;

    /**
     * [1st, 2nd) lines range.
     * lines should have any non-zero symbol, including space (32).
     * if screen is absolutely clean it will return nullopt
     */
    [[nodiscard]] std::optional<std::pair<int, int>> OccupiedOnScreenLines() const;

    [[nodiscard]] std::vector<uint16_t> DumpUnicodeString(ScreenPoint _begin, ScreenPoint _end) const;

    using LayedOutUTF16Dump = std::pair<std::vector<uint16_t>, std::vector<ScreenPoint>>;
    [[nodiscard]] LayedOutUTF16Dump DumpUTF16StringWithLayout(ScreenPoint _begin, ScreenPoint _end) const;

    // use for diagnose and test purposes only
    [[nodiscard]] std::string DumpScreenAsANSI() const;
    [[nodiscard]] std::string DumpScreenAsANSIBreaked() const;
    [[nodiscard]] std::u32string DumpScreenAsUTF32(int _options = DumpOptions::Default) const;
    void LoadScreenFromANSI(std::string_view _dump);
    [[nodiscard]] std::string DumpBackScreenAsANSI() const;

    [[nodiscard]] Snapshot MakeSnapshot() const;
    void RevertToSnapshot(const Snapshot &_snapshot);

    static unsigned OccupiedChars(std::span<const Space> _line) noexcept;
    static unsigned OccupiedChars(const Space *_begin, const Space *_end) noexcept;

    // Returns 'true' if the range contains and non-null characters
    static bool HasOccupiedChars(const Space *_begin, const Space *_end) noexcept;

    [[nodiscard]] unsigned OccupiedChars(int _line_no) const;
    [[nodiscard]] bool HasOccupiedChars(int _line_no) const;

    [[nodiscard]] std::vector<std::vector<Space>>
    ComposeContinuousLines(int _from,
                           int _to) const; // [_from, _to), _from is less than _to

private:
    struct LineMeta {
        unsigned start_index = 0;
        unsigned line_length = 0;
        bool is_wrapped = false;
    };

    LineMeta *MetaFromLineNo(int _line_number);
    [[nodiscard]] const LineMeta *MetaFromLineNo(int _line_number) const;

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
    const uint64_t mask = 0x3FFFFFF00000000ULL;
    const uint64_t lhs = *reinterpret_cast<const uint64_t *>(this);
    const uint64_t rhs = *reinterpret_cast<const uint64_t *>(&_rhs);
    return (lhs & mask) == (rhs & mask);
}

} // namespace nc::term
