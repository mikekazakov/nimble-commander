// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ScreenBuffer.h"
#include <CoreFoundation/CoreFoundation.h>
#include <algorithm>
#include <cstddef>

namespace nc::term {

static_assert(sizeof(ScreenBuffer::Space) == 8);

static void Append(CFStringRef _what, std::u32string &_where);

ScreenBuffer::ScreenBuffer(unsigned _width, unsigned _height, ExtendedCharRegistry &_reg)
    : m_Width(_width), m_Height(_height), m_Registry(_reg)
{
    m_OnScreenSpaces = ProduceRectangularSpaces(m_Width, m_Height);
    m_OnScreenLines.resize(m_Height);
    FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), m_Width);
}

std::unique_ptr<ScreenBuffer::Space[]> ScreenBuffer::ProduceRectangularSpaces(unsigned _width, unsigned _height)
{
    return std::make_unique<Space[]>(static_cast<size_t>(_width) * static_cast<size_t>(_height));
}

std::unique_ptr<ScreenBuffer::Space[]>
ScreenBuffer::ProduceRectangularSpaces(unsigned _width, unsigned _height, Space _initial_char)
{
    auto p = ProduceRectangularSpaces(_width, _height);
    std::fill(&p[0], &p[static_cast<size_t>(_width) * static_cast<size_t>(_height)], _initial_char);
    return p;
}

void ScreenBuffer::FixupOnScreenLinesIndeces(std::vector<LineMeta>::iterator _i,
                                             std::vector<LineMeta>::iterator _e,
                                             unsigned _width)
{
    unsigned start = 0;
    for( ; _i != _e; ++_i, start += _width ) {
        _i->start_index = start;
        _i->line_length = _width;
    }
}

std::span<const ScreenBuffer::Space> ScreenBuffer::LineFromNo(int _line_number) const noexcept
{
    return const_cast<ScreenBuffer *>(this)->LineFromNo(_line_number);
}

std::span<ScreenBuffer::Space> ScreenBuffer::LineFromNo(int _line_number) noexcept
{
    if( _line_number >= 0 && _line_number < static_cast<int>(m_OnScreenLines.size()) ) {
        const LineMeta line = m_OnScreenLines[_line_number];
        assert(line.start_index + line.line_length <= m_Height * m_Width);
        return {m_OnScreenSpaces.get() + line.start_index, line.line_length};
    }
    else if( _line_number < 0 && -_line_number <= static_cast<int>(m_BackScreenLines.size()) ) {
        const unsigned ind = unsigned(static_cast<int>(m_BackScreenLines.size()) + _line_number);
        const LineMeta line = m_BackScreenLines[ind];
        assert(line.start_index + line.line_length <= m_BackScreenSpaces.size());
        // NB! use .data() + offset instead of operator[] since &[size] is UB
        return {m_BackScreenSpaces.data() + line.start_index, line.line_length};
    }
    else
        return {};
}

ScreenBuffer::Space ScreenBuffer::At(int x, int y) const
{
    auto line = LineFromNo(y);
    if( line.empty() )
        throw std::invalid_argument("ScreenBuffer::At(): invalid row");
    if( x < 0 || x >= static_cast<long>(line.size()) )
        throw std::invalid_argument("ScreenBuffer::At(): invalid column");
    return line[x];
}

ScreenBuffer::LineMeta *ScreenBuffer::MetaFromLineNo(int _line_number)
{
    if( _line_number >= 0 && _line_number < static_cast<int>(m_OnScreenLines.size()) )
        return &m_OnScreenLines[_line_number];
    else if( _line_number < 0 && -_line_number <= static_cast<int>(m_BackScreenLines.size()) ) {
        const unsigned ind = unsigned(static_cast<signed>(m_BackScreenLines.size()) + _line_number);
        return &m_BackScreenLines[ind];
    }
    else
        return nullptr;
}

const ScreenBuffer::LineMeta *ScreenBuffer::MetaFromLineNo(int _line_number) const
{
    if( _line_number >= 0 && _line_number < static_cast<int>(m_OnScreenLines.size()) )
        return &m_OnScreenLines[_line_number];
    else if( _line_number < 0 && -_line_number <= static_cast<int>(m_BackScreenLines.size()) ) {
        const unsigned ind = unsigned(static_cast<signed>(m_BackScreenLines.size()) + _line_number);
        return &m_BackScreenLines[ind];
    }
    else
        return nullptr;
}

std::vector<uint16_t> ScreenBuffer::DumpUnicodeString(const ScreenPoint _begin, const ScreenPoint _end) const
{
    if( _begin >= _end )
        return {};

    std::vector<uint16_t> unicode;
    auto curr = _begin;
    while( curr < _end ) {
        auto line = LineFromNo(curr.y);

        if( line.empty() ) {
            curr.y++;
            continue;
        }

        bool any_inserted = false;
        const auto chars_len = static_cast<int>(OccupiedChars(line.data(), line.data() + line.size()));
        for( ; curr.x < chars_len && curr < _end; ++curr.x ) {
            const auto sp = line[curr.x];
            if( sp.l == MultiCellGlyph )
                continue;

            if( ExtendedCharRegistry::IsBase(sp.l) ) {
                uint16_t buf[2];
                if( CFStringGetSurrogatePairForLongCharacter(sp.l, buf) ) {
                    unicode.push_back(buf[0]);
                    unicode.push_back(buf[1]);
                }
                else {
                    unicode.push_back(buf[0]);
                }
            }
            else {
                auto cf_str = m_Registry.Decode(sp.l);
                assert(cf_str);
                const auto len = CFStringGetLength(cf_str.get());
                const auto curr_size = unicode.size();
                unicode.resize(curr_size + len);
                CFStringGetCharacters(cf_str.get(), CFRangeMake(0, len), unicode.data() + curr_size);
            }
            any_inserted = true;
        }

        if( curr >= _end )
            break;

        if( any_inserted && !LineWrapped(curr.y) )
            unicode.push_back(0x000A);

        curr.y++;
        curr.x = 0;
    }

    return unicode;
}

std::pair<std::vector<uint16_t>, std::vector<ScreenPoint>>
ScreenBuffer::DumpUTF16StringWithLayout(ScreenPoint _begin, ScreenPoint _end) const
{
    if( _begin >= _end )
        return {};

    std::vector<uint16_t> unichars;
    std::vector<ScreenPoint> positions;

    auto curr = _begin;

    auto put = [&](uint16_t _unichar) {
        unichars.emplace_back(_unichar);
        positions.emplace_back(curr);
    };

    while( curr < _end ) {
        auto line = LineFromNo(curr.y);

        if( line.empty() ) {
            curr.y++;
            continue;
        }

        bool any_inserted = false;
        const auto chars_len = static_cast<int>(OccupiedChars(line.data(), line.data() + line.size()));
        for( ; curr.x < chars_len && curr < _end; ++curr.x ) {
            auto &sp = line[curr.x];
            if( sp.l == MultiCellGlyph )
                continue;

            uint16_t utf16[2];
            if( CFStringGetSurrogatePairForLongCharacter(sp.l != 0 ? sp.l : ' ', utf16) ) {
                put(utf16[0]);
                put(utf16[1]);
            }
            else
                put(utf16[0]);

            // TODO: extended chars

            any_inserted = true;
        }

        if( curr >= _end )
            break;

        if( any_inserted && !LineWrapped(curr.y) )
            put(0x000A);

        curr.y++;
        curr.x = 0;
    }

    return {std::move(unichars), std::move(positions)};
}

std::string ScreenBuffer::DumpScreenAsANSI() const
{
    std::string result;
    for( auto &l : m_OnScreenLines )
        for( auto *i = &m_OnScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i )
            result += ((i->l >= 32 && i->l <= 127) ? static_cast<char>(i->l) : ' ');
    return result;
}

std::string ScreenBuffer::DumpBackScreenAsANSI() const
{
    std::string result;
    for( auto &l : m_BackScreenLines )
        for( auto *i = &m_BackScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i )
            result += ((i->l >= 32 && i->l <= 127) ? static_cast<char>(i->l) : ' ');
    return result;
}

std::string ScreenBuffer::DumpScreenAsANSIBreaked() const
{
    std::string result;
    for( auto &l : m_OnScreenLines ) {
        for( auto *i = &m_OnScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i )
            result += ((i->l >= 32 && i->l <= 127) ? static_cast<char>(i->l) : ' ');
        result += '\r';
    }
    return result;
}

std::u32string ScreenBuffer::DumpScreenAsUTF32(const int _options) const
{
    std::u32string result;
    for( auto &l : m_OnScreenLines ) {
        for( auto *i = &m_OnScreenSpaces[l.start_index], *e = i + l.line_length; i != e; ++i ) {
            if( i->l == MultiCellGlyph ) {
                if( _options & DumpOptions::ReportMultiCellGlyphs )
                    result += ' ';
            }
            else if( i->l >= 32 ) {
                if( ExtendedCharRegistry::IsBase(i->l) ) {
                    result += i->l;
                }
                else {
                    auto cf_str = m_Registry.Decode(i->l);
                    assert(cf_str);
                    Append(cf_str.get(), result);
                }
            }
            else {
                result += ' ';
            }
        }
        if( _options & DumpOptions::BreakLines )
            result += '\r';
    }
    return result;
}

void ScreenBuffer::LoadScreenFromANSI(std::string_view _dump)
{
    for( auto &l : m_OnScreenLines ) {
        for( auto i = &m_OnScreenSpaces[l.start_index], e = i + l.line_length; i != e; ++i ) {
            if( _dump.empty() )
                return;
            i->l = _dump.front();
            _dump = _dump.substr(1);
        }
    }
}

bool ScreenBuffer::LineWrapped(int _line_number) const
{
    if( auto l = MetaFromLineNo(_line_number) )
        return l->is_wrapped;
    return false;
}

void ScreenBuffer::SetLineWrapped(int _line_number, bool _wrapped)
{
    if( auto l = MetaFromLineNo(_line_number) )
        l->is_wrapped = _wrapped;
}

ScreenBuffer::Space ScreenBuffer::EraseChar() const
{
    return m_EraseChar;
}

void ScreenBuffer::SetEraseChar(Space _ch)
{
    m_EraseChar = _ch;
}

ScreenBuffer::Space ScreenBuffer::DefaultEraseChar() noexcept
{
    Space sp;
    memset(&sp, 0, sizeof(sp));
    return sp;
}

// need real ocupied size
// need "anchor" here
void ScreenBuffer::ResizeScreen(unsigned _new_sx, unsigned _new_sy, bool _merge_with_backscreen)
{
    if( _new_sx == 0 || _new_sy == 0 )
        throw std::out_of_range("TermScreenBuffer::ResizeScreen - screen sizes can't be zero");

    using ConstIt = std::vector<std::tuple<std::vector<Space>, bool>>::const_iterator;
    auto fill_scr_from_declines = [this](ConstIt _i, ConstIt _e) {
        size_t l = 0;
        for( ; _i != _e; ++_i, ++l ) {
            std::copy(std::begin(std::get<0>(*_i)),
                      std::end(std::get<0>(*_i)),
                      &m_OnScreenSpaces[m_OnScreenLines[l].start_index]);
            m_OnScreenLines[l].is_wrapped = std::get<1>(*_i);
        }
    };
    auto fill_bkscr_from_declines = [this](ConstIt _i, ConstIt _e) {
        for( ; _i != _e; ++_i ) {
            LineMeta lm;
            lm.start_index = static_cast<int>(m_BackScreenSpaces.size());
            lm.line_length = static_cast<int>(std::get<0>(*_i).size());
            lm.is_wrapped = std::get<1>(*_i);
            m_BackScreenLines.emplace_back(lm);
            m_BackScreenSpaces.insert(
                std::end(m_BackScreenSpaces), std::begin(std::get<0>(*_i)), std::end(std::get<0>(*_i)));
        }
    };

    if( _merge_with_backscreen ) {
        auto comp_lines = ComposeContinuousLines(-BackScreenLines(), Height());
        auto decomp_lines = DecomposeContinuousLines(comp_lines, _new_sx);

        m_BackScreenLines.clear();
        m_BackScreenSpaces.clear();
        if( decomp_lines.size() > _new_sy ) {
            fill_bkscr_from_declines(begin(decomp_lines), end(decomp_lines) - _new_sy);

            m_OnScreenSpaces = ProduceRectangularSpaces(_new_sx, _new_sy, m_EraseChar);
            m_OnScreenLines.resize(_new_sy);
            FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), _new_sx);
            fill_scr_from_declines(end(decomp_lines) - _new_sy, end(decomp_lines));
        }
        else {
            m_OnScreenSpaces = ProduceRectangularSpaces(_new_sx, _new_sy, m_EraseChar);
            m_OnScreenLines.resize(_new_sy);
            FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), _new_sx);
            fill_scr_from_declines(begin(decomp_lines), end(decomp_lines));
        }
    }
    else {
        auto bkscr_decomp_lines = DecomposeContinuousLines(ComposeContinuousLines(-BackScreenLines(), 0), _new_sx);
        m_BackScreenLines.clear();
        m_BackScreenSpaces.clear();
        fill_bkscr_from_declines(begin(bkscr_decomp_lines), end(bkscr_decomp_lines));

        auto onscr_decomp_lines = DecomposeContinuousLines(ComposeContinuousLines(0, Height()), _new_sx);
        m_OnScreenSpaces = ProduceRectangularSpaces(_new_sx, _new_sy, m_EraseChar);
        m_OnScreenLines.resize(_new_sy);
        FixupOnScreenLinesIndeces(begin(m_OnScreenLines), end(m_OnScreenLines), _new_sx);
        fill_scr_from_declines(begin(onscr_decomp_lines),
                               min(begin(onscr_decomp_lines) + _new_sy, end(onscr_decomp_lines)));
    }

    m_Width = _new_sx;
    m_Height = _new_sy;
}

void ScreenBuffer::FeedBackscreen(const std::span<const Space> _with_spaces, const bool _wrapped)
{
    const Space *_from = _with_spaces.data();
    const Space *_to = _with_spaces.data() + _with_spaces.size();
    // TODO: trimming and empty lines ?
    while( _from < _to ) {
        const unsigned line_len = std::min(m_Width, unsigned(_to - _from));

        m_BackScreenLines.emplace_back();
        m_BackScreenLines.back().start_index = static_cast<unsigned>(m_BackScreenSpaces.size());
        m_BackScreenLines.back().line_length = line_len;
        m_BackScreenLines.back().is_wrapped = _wrapped ? true : (m_Width < _to - _from);
        m_BackScreenSpaces.insert(std::end(m_BackScreenSpaces), _from, _from + line_len);

        _from += line_len;
    }
}

static constexpr bool IsOccupiedChar(const ScreenBuffer::Space &_s) noexcept
{
    return _s.l != 0;
}

unsigned ScreenBuffer::OccupiedChars(std::span<const Space> _line) noexcept
{
    return OccupiedChars(_line.data(), _line.data() + _line.size());
}

unsigned ScreenBuffer::OccupiedChars(const Space *_begin, const Space *_end) noexcept
{
    assert(_end >= _end);
    if( _end == _begin )
        return 0;

    unsigned len = 0;
    for( auto i = _end - 1; i >= _begin; --i ) // going backward
        if( IsOccupiedChar(*i) ) {
            len = static_cast<unsigned>(i - _begin + 1);
            break;
        }

    return len;
}

bool ScreenBuffer::HasOccupiedChars(const Space *_begin, const Space *_end) noexcept
{
    assert(_end >= _end);
    for( ; _begin != _end; ++_begin ) // going forward
        if( IsOccupiedChar(*_begin) )
            return true;
    return false;
}

unsigned ScreenBuffer::OccupiedChars(int _line_no) const
{
    if( auto l = LineFromNo(_line_no); !l.empty() )
        return OccupiedChars(l);
    return 0;
}

bool ScreenBuffer::HasOccupiedChars(int _line_no) const
{
    if( auto l = LineFromNo(_line_no); !l.empty() )
        return HasOccupiedChars(l.data(), l.data() + l.size());
    return false;
}

std::vector<std::vector<ScreenBuffer::Space>> ScreenBuffer::ComposeContinuousLines(int _from, int _to) const
{
    std::vector<std::vector<Space>> lines;

    for( bool continue_prev = false; _from < _to; ++_from ) {
        auto source = LineFromNo(_from);
        if( source.data() == nullptr ) {
            // NB! comparing ptr with nullptr instead of calling .empty() - differing meaning
            throw std::out_of_range("invalid bounds in TermScreen::Buffer::ComposeContinuousLines");
        }

        if( !continue_prev )
            lines.emplace_back();
        auto &current = lines.back();

        current.insert(end(current), begin(source), begin(source) + OccupiedChars(source));
        continue_prev = LineWrapped(_from);
    }

    return lines;
}

std::vector<std::tuple<std::vector<ScreenBuffer::Space>, bool>>
ScreenBuffer::DecomposeContinuousLines(const std::vector<std::vector<Space>> &_src, unsigned _width)
{
    if( _width == 0 ) {
        auto msg = "TermScreenBuffer::DecomposeContinuousLines width can't be zero";
        throw std::invalid_argument(msg);
    }

    std::vector<std::tuple<std::vector<Space>, bool>> result;

    for( auto &l : _src ) {
        if( l.empty() ) // special case for CRLF-only lines
            result.emplace_back(std::make_tuple<std::vector<Space>, bool>({}, false));

        for( size_t i = 0, e = l.size(); i < e; i += _width ) {
            auto t = std::make_tuple<std::vector<Space>, bool>({}, false);
            if( i + _width < e ) {
                std::get<0>(t).assign(begin(l) + i, begin(l) + i + _width);
                std::get<1>(t) = true;
            }
            else {
                std::get<0>(t).assign(begin(l) + i, end(l));
            }
            result.emplace_back(std::move(t));
        }
    }
    return result;
}

ScreenBuffer::Snapshot::Snapshot() : width(0), height(0)
{
}

ScreenBuffer::Snapshot::Snapshot(unsigned _w, unsigned _h)
    : width(_w), height(_h), chars(std::make_unique<Space[]>(static_cast<size_t>(_w) * static_cast<size_t>(_h)))
{
}

ScreenBuffer::Snapshot ScreenBuffer::MakeSnapshot() const
{
    Snapshot snapshot(m_Width, m_Height);
    std::copy_n(m_OnScreenSpaces.get(), m_Width * m_Height, snapshot.chars.get());
    return snapshot;
}

void ScreenBuffer::RevertToSnapshot(const Snapshot &_snapshot)
{
    if( m_Height == _snapshot.height && m_Width == _snapshot.width ) {
        std::copy_n(_snapshot.chars.get(), m_Width * m_Height, m_OnScreenSpaces.get());
    }
    else { // TODO: anchor?
        std::fill_n(m_OnScreenSpaces.get(), m_Width * m_Height, m_EraseChar);
        for( int y = 0, e = std::min(_snapshot.height, m_Height); y != e; ++y ) {
            std::copy_n(_snapshot.chars.get() + (static_cast<size_t>(y * _snapshot.width)),
                        std::min(_snapshot.width, m_Width),
                        m_OnScreenSpaces.get() + (static_cast<size_t>(y * m_Width)));
        }
    }
}

std::optional<std::pair<int, int>> ScreenBuffer::OccupiedOnScreenLines() const
{
    int first = std::numeric_limits<int>::max();
    int last = std::numeric_limits<int>::min();
    for( int i = 0, e = Height(); i < e; ++i )
        if( HasOccupiedChars(i) ) {
            first = std::min(first, i);
            last = std::max(last, i);
        }

    if( first > last )
        return std::nullopt;

    return std::make_pair(first, last + 1);
}

unsigned ScreenBuffer::Width() const
{
    return m_Width;
}

unsigned ScreenBuffer::Height() const
{
    return m_Height;
}

unsigned ScreenBuffer::BackScreenLines() const
{
    return static_cast<unsigned>(m_BackScreenLines.size());
}

static void Append(CFStringRef _what, std::u32string &_where)
{
    const auto len = CFStringGetLength(_what);

    CFIndex used = 0;
    CFStringGetBytes(_what, CFRangeMake(0, len), kCFStringEncodingUTF32LE, 0, false, nullptr, 0, &used);
    const size_t utf32_len = used / 4;
    if( utf32_len == 0 )
        return;

    const auto curr_size = _where.size();
    _where.resize(curr_size + utf32_len);

    CFStringGetBytes(_what,
                     CFRangeMake(0, len),
                     kCFStringEncodingUTF32LE,
                     0,
                     false,
                     reinterpret_cast<UInt8 *>(_where.data() + curr_size),
                     utf32_len * sizeof(char32_t),
                     nullptr);
}

} // namespace nc::term
