// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontCache.h>
#include <Utility/CharInfo.h>
#include "Screen.h"
#include <algorithm>

namespace nc::term {

Screen::Screen(unsigned _w, unsigned _h, ExtendedCharRegistry &_reg) : m_Registry(_reg), m_Buffer(_w, _h)

{
    GoToDefaultPosition();
}

char32_t Screen::GetCh() noexcept
{
    const std::span<ScreenBuffer::Space> line = m_Buffer.LineFromNo(m_PosY);
    if( line.empty() )
        return 0;

    if( m_PosX < static_cast<int>(line.size()) )
        return line[m_PosX].l;

    return 0;
}

void Screen::PutCh(char32_t _char)
{
    const std::span<ScreenBuffer::Space> line = m_Buffer.LineFromNo(m_PosY);
    if( line.empty() )
        return;

    auto chars = line.begin();
    const int line_len = static_cast<int>(line.size());

    Screen::Space sp = m_EraseChar;
    sp.l = _char;
    chars[m_PosX] = sp;
    const bool is_dw = m_Registry.IsDoubleWidth(_char);
    if( is_dw && m_PosX + 1 < line_len ) {
        sp.l = MultiCellGlyph;
        chars[m_PosX + 1] = sp;
    }

    if( m_PosX == line_len - 1 || (m_PosX == line_len - 2 && is_dw) ) {
        m_LineOverflown = true;
    }
    m_Buffer.SetLineWrapped(m_PosY, false); // do we need it EVERY time?????
}

void Screen::PutWrap()
{
    // TODO: optimize it out
    //    assert(m_PosY < m_Screen.size());
    //    GetLineRW(m_PosY)->wrapped = true;
    m_Buffer.SetLineWrapped(m_PosY, true);
}

// ED – Erase Display    Clears part of the screen.
//    If n is zero (or missing), clear from cursor to end of screen.
//    If n is one, clear from beginning of the screen to cursor.
//    If n is two, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS).
void Screen::DoEraseScreen(int _mode)
{
    if( _mode == 1 ) {
        for( int i = 0; i < Height(); ++i ) {
            auto l = m_Buffer.LineFromNo(i);
            if( i != m_PosY )
                std::ranges::fill(l, m_EraseChar);
            else {
                std::fill(std::begin(l), std::min(std::begin(l) + m_PosX + 1, std::end(l)), m_EraseChar);
                return;
            }
            m_Buffer.SetLineWrapped(i, false);
        }
    }
    else if( _mode == 2 ) { // clear all screen
        for( int i = 0; i < Height(); ++i ) {
            auto l = m_Buffer.LineFromNo(i);
            std::ranges::fill(l, m_EraseChar);
            m_Buffer.SetLineWrapped(i, false);
        }
    }
    else {
        for( int i = m_PosY; i < Height(); ++i ) {
            m_Buffer.SetLineWrapped(i, false);
            auto chars = m_Buffer.LineFromNo(i).data();
            for( int j = (i == m_PosY ? m_PosX : 0); j < Width(); ++j )
                chars[j] = m_EraseChar;
        }
    }
}

void Screen::GoTo(int _x, int _y)
{
    // any cursor movement which changes Y should end here!

    m_PosX = _x;
    m_PosY = _y;
    m_PosX = std::max(m_PosX, 0);
    if( m_PosX >= Width() )
        m_PosX = Width() - 1;
    m_PosY = std::max(m_PosY, 0);
    if( m_PosY >= Height() )
        m_PosY = Height() - 1;
    m_LineOverflown = false;
}

void Screen::DoCursorUp(int _n)
{
    GoTo(m_PosX, m_PosY - _n);
}

void Screen::DoCursorDown(int _n)
{
    GoTo(m_PosX, m_PosY + _n);
}

void Screen::DoCursorLeft(int _n)
{
    GoTo(m_PosX - _n, m_PosY);
}

void Screen::DoCursorRight(int _n)
{
    GoTo(m_PosX + _n, m_PosY);
}

void Screen::EraseInLine(int _mode)
{
    // If n is zero (or missing), clear from cursor to the end of the line.
    // If n is one, clear from cursor to beginning of the line.
    // If n is two, clear entire line.
    // Cursor position does not change.
    auto line = m_Buffer.LineFromNo(m_PosY);
    if( line.empty() )
        return;
    auto i = begin(line);
    auto e = end(line);
    if( _mode == 0 )
        i = std::min(i + m_PosX, e);
    else if( _mode == 1 )
        e = std::min(i + m_PosX + 1, e);
    std::fill(i, e, m_EraseChar);
}

void Screen::EraseInLineCount(unsigned _n)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if( line.empty() )
        return;
    auto i = std::begin(line) + m_PosX;
    auto e = std::min(i + _n, std::end(line));
    std::fill(i, e, m_EraseChar);
}

void Screen::FillScreenWithSpace(ScreenBuffer::Space _space)
{
    const auto height = Height();
    for( int y = 0; y != height; ++y ) {
        auto line = m_Buffer.LineFromNo(y);
        for( auto &line_char : line ) {
            line_char = _space;
        }
    }
}

void Screen::SetFgColor(std::optional<Color> _color)
{
    if( _color ) {
        m_EraseChar.foreground = *_color;
        m_EraseChar.customfg = true;
    }
    else {
        m_EraseChar.foreground = Color{};
        m_EraseChar.customfg = false;
    }
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetBgColor(std::optional<Color> _color)
{
    if( _color ) {
        m_EraseChar.background = *_color;
        m_EraseChar.custombg = true;
    }
    else {
        m_EraseChar.background = Color{};
        m_EraseChar.custombg = false;
    }
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetFaint(bool _faint)
{
    m_EraseChar.faint = _faint;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetUnderline(bool _is_underline)
{
    m_EraseChar.underline = _is_underline;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetCrossed(bool _is_crossed)
{
    m_EraseChar.crossed = _is_crossed;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetReverse(bool _is_reverse)
{
    m_EraseChar.reverse = _is_reverse;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetBold(bool _is_bold)
{
    m_EraseChar.bold = _is_bold;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetItalic(bool _is_italic)
{
    m_EraseChar.italic = _is_italic;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetInvisible(bool _is_invisible)
{
    m_EraseChar.invisible = _is_invisible;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetBlink(bool _is_blink)
{
    m_EraseChar.blink = _is_blink;
    m_Buffer.SetEraseChar(m_EraseChar);
}

Screen::SavedScreen Screen::CaptureScreen() const
{
    SavedScreen screen;
    screen.pos_x = m_PosX;
    screen.pos_y = m_PosY;
    screen.snapshot = m_Buffer.MakeSnapshot();
    return screen;
}

void Screen::SetAlternateScreen(bool _is_alternate)
{
    if( m_AlternateScreen == _is_alternate )
        return;

    if( m_AlternateScreen ) {
        m_AlternativeScreenshot = CaptureScreen();
        m_Buffer.RevertToSnapshot(m_PrimaryScreenshot.snapshot);
        GoTo(m_PrimaryScreenshot.pos_x, m_PrimaryScreenshot.pos_y);
    }
    else {
        m_PrimaryScreenshot = CaptureScreen();
        m_Buffer.RevertToSnapshot(m_AlternativeScreenshot.snapshot);
        GoTo(0, 0);
    }
    m_AlternateScreen = _is_alternate;
}

void Screen::DoShiftRowLeft(int _chars)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if( line.empty() )
        return;
    auto chars = line.data();

    // TODO: write as an algo

    for( int x = m_PosX + _chars; x < Width(); ++x )
        chars[x - _chars] = chars[x];

    for( int i = 0; i < _chars; ++i )
        chars[Width() - i - 1] = m_EraseChar; // why m_Width here???
}

void Screen::DoShiftRowRight(int _chars)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if( line.empty() )
        return;
    auto chars = line.data();

    // TODO: write as an algo

    for( int x = Width() - 1; x >= m_PosX + _chars; --x )
        chars[x] = chars[x - _chars];

    for( int i = 0; i < _chars; ++i )
        chars[m_PosX + i] = m_EraseChar;
}

void Screen::EraseAt(unsigned _x, unsigned _y, unsigned _count)
{
    if( auto line = m_Buffer.LineFromNo(_y); !line.empty() ) {
        auto i = std::begin(line) + _x;
        auto e = std::min(i + _count, std::end(line));
        std::fill(i, e, m_EraseChar);
    }
}

void Screen::CopyLineChars(int _from, int _to)
{
    auto src = m_Buffer.LineFromNo(_from);
    auto dst = m_Buffer.LineFromNo(_to);
    if( !src.empty() && !dst.empty() )
        std::copy_n(
            begin(src), std::min(std::end(src) - std::begin(src), std::end(dst) - std::begin(dst)), std::begin(dst));
}

void Screen::ClearLine(int _ind)
{
    if( auto line = m_Buffer.LineFromNo(_ind); !line.empty() ) {
        std::ranges::fill(line, m_EraseChar);
        m_Buffer.SetLineWrapped(_ind, false);
    }
}

void Screen::ScrollDown(const unsigned _top, const unsigned _bottom, const unsigned _lines)
{
    const auto top = static_cast<int>(_top);
    const auto bottom = std::min(static_cast<int>(_bottom), Height());
    const auto lines = static_cast<int>(_lines);
    if( top >= Height() )
        return;
    if( top >= bottom )
        return;
    if( lines < 1 )
        return;

    for( int n_dst = bottom - 1, n_src = bottom - 1 - lines; n_dst > top && n_src >= top; --n_dst, --n_src ) {
        CopyLineChars(n_src, n_dst);
        m_Buffer.SetLineWrapped(n_dst, m_Buffer.LineWrapped(n_src));
    }

    for( int i = _top; i < std::min(top + lines, bottom); ++i )
        ClearLine(i);
}

void Screen::DoScrollUp(const unsigned _top, const unsigned _bottom, const unsigned _lines)
{
    const auto top = static_cast<int>(_top);
    const auto bottom = std::min(static_cast<int>(_bottom), Height());
    const auto lines = static_cast<int>(_lines);
    if( top >= Height() )
        return;
    if( top >= bottom )
        return;
    if( lines < 1 )
        return;

    if( top == 0 && bottom == Height() && !m_AlternateScreen )
        for( int i = 0; i < std::min(lines, Height()); ++i ) {
            // we're scrolling up the whole screen - let's feed scrollback with leftover
            auto line = m_Buffer.LineFromNo(i);
            assert(!line.empty());
            m_Buffer.FeedBackscreen(line, m_Buffer.LineWrapped(i));
        }

    for( int n_src = top + lines, n_dst = top; n_src < bottom && n_dst < bottom; ++n_src, ++n_dst ) {
        CopyLineChars(n_src, n_dst);
        m_Buffer.SetLineWrapped(n_dst, m_Buffer.LineWrapped(n_src));
    }

    for( int i = bottom - 1; i >= std::max(bottom - lines, top); --i )
        ClearLine(i);
}

void Screen::ResizeScreen(const unsigned _new_sx, const unsigned _new_sy)
{
    if( Width() == static_cast<int>(_new_sx) && Height() == static_cast<int>(_new_sy) )
        return;
    if( _new_sx == 0 || _new_sy == 0 )
        throw std::invalid_argument("Screen::ResizeScreen sizes can't be zero");

    const bool feed_from_bs = m_PosY == Height() - 1; // questionable!

    m_Buffer.ResizeScreen(_new_sx, _new_sy, feed_from_bs && !m_AlternateScreen);

    // adjust cursor Y if it was at the bottom prior to resizing
    GoTo(CursorX(), feed_from_bs ? Height() - 1 : CursorY()); // will clip if necessary
}

void Screen::GoToDefaultPosition()
{
    GoTo(0, 0);
}

void Screen::SetVideoReverse(bool _reverse) noexcept
{
    m_ReverseVideo = _reverse;
}

bool Screen::VideoReverse() const noexcept
{
    return m_ReverseVideo;
}

std::unique_lock<std::mutex> Screen::AcquireLock() const noexcept
{
    return std::unique_lock{m_Lock};
}

const ScreenBuffer &Screen::Buffer() const noexcept
{
    return m_Buffer;
}

ScreenBuffer &Screen::Buffer() noexcept
{
    return m_Buffer;
}

int Screen::Width() const noexcept
{
    return m_Buffer.Width();
}

int Screen::Height() const noexcept
{
    return m_Buffer.Height();
}

int Screen::CursorX() const noexcept
{
    return m_PosX;
}

int Screen::CursorY() const noexcept
{
    return m_PosY;
}

bool Screen::LineOverflown() const noexcept
{
    return m_LineOverflown;
}

} // namespace nc::term
