// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontCache.h>
#include <Utility/OrthodoxMonospace.h>
#include "Screen.h"

namespace nc::term {

Screen::Screen(unsigned _w, unsigned _h):
    m_Buffer(_w, _h)
{
    GoToDefaultPosition();
}

void Screen::PutString(const std::string &_str)
{
    for(auto c:_str)
        PutCh(c);
}

void Screen::PutCh(uint32_t _char)
{
//    if(_char >= 32 && _char < 127)
//        printf("%c", _char);
    
    auto line = m_Buffer.LineFromNo(m_PosY);
    if( !line )
        return;
    
    auto chars = begin(line);
    
    if( !oms::IsUnicodeCombiningCharacter(_char) ) {
        if( chars + m_PosX < end(line) ) {
            auto sp = m_EraseChar;
            sp.l = _char;
            // sp.c1 == 0
            // sp.c2 == 0
            chars[m_PosX++] = sp;
            
            if(oms::WCWidthMin1(_char) == 2 &&
               chars + m_PosX < end(line) ) {
                sp.l = MultiCellGlyph;
                chars[m_PosX++] = sp;
            }
        }
    }
    else { // combining characters goes here
        if(m_PosX > 0 &&
           chars + m_PosX < end(line) ) {
            int target_pos = m_PosX - 1;
            if((chars[target_pos].l == MultiCellGlyph) && (target_pos > 0)) target_pos--;
            if(chars[target_pos].c1 == 0) chars[target_pos].c1 = _char;
            else if(chars[target_pos].c2 == 0) chars[target_pos].c2 = _char;
        }
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

// ED – Erase Display	Clears part of the screen.
//    If n is zero (or missing), clear from cursor to end of screen.
//    If n is one, clear from beginning of the screen to cursor.
//    If n is two, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS).
void Screen::DoEraseScreen(int _mode)
{
    if(_mode == 1) {
        for(int i = 0; i < Height(); ++i) {
            auto l = m_Buffer.LineFromNo(i);
            if(i != m_PosY)
                std::fill(begin(l), end(l), m_EraseChar);
            else {
                std::fill(begin(l),
                          std::min( std::begin(l)+m_PosX, std::end(l) ),
                          m_EraseChar);
                return;
            }
            m_Buffer.SetLineWrapped(i, false);
        }
    } else if(_mode == 2)
    { // clear all screen
        for(int i = 0; i < Height(); ++i) {
            auto l = m_Buffer.LineFromNo(i);
            std::fill(begin(l), end(l), m_EraseChar);
            m_Buffer.SetLineWrapped(i, false);
        }
    } else {
        for(int i = m_PosY; i < Height(); ++i) {
            m_Buffer.SetLineWrapped(i, false);
            auto chars = m_Buffer.LineFromNo(i).first;
            for(int j = (i == m_PosY ? m_PosX : 0); j < Width(); ++j)
                chars[j] = m_EraseChar;
        }
    }
}

void Screen::GoTo(int _x, int _y)
{
    // any cursor movement which changes Y should end here!
    
    m_PosX = _x;
    m_PosY = _y;
    if(m_PosX < 0) m_PosX = 0;
    if(m_PosX >= Width()) m_PosX = Width() - 1;
    if(m_PosY < 0) m_PosY = 0;
    if(m_PosY >= Height()) m_PosY = Height() - 1;
}

void Screen::DoCursorUp(int _n)
{
    GoTo(m_PosX, m_PosY-_n);
}

void Screen::DoCursorDown(int _n)
{
    GoTo(m_PosX, m_PosY+_n);
}

void Screen::DoCursorLeft(int _n)
{
    GoTo(m_PosX-_n, m_PosY);
}

void Screen::DoCursorRight(int _n)
{
    GoTo(m_PosX+_n, m_PosY);
}

//void TermScreen::DoLineFeed()
//{
//    if(m_PosY == m_Height - 1)
//        ScrollBufferUp();
//    else
//        DoCursorDown(1);
    
    /*
#define lf() do { \
if (y+1==bottom) \
{ \
scrup(foo,top,bottom,1,(top==0 && bottom==height)?YES:NO); \
} \
else if (y<height-1) \
{ \
y++; \
[ts ts_goto: x:y]; \
} \
} while (0)
*/

    
//}

/*void TermScreen::DoCarriageReturn()
{
    GoTo(0, m_PosY);
}*/

void Screen::EraseInLine(int _mode)
{
    // If n is zero (or missing), clear from cursor to the end of the line.
    // If n is one, clear from cursor to beginning of the line.
    // If n is two, clear entire line.
    // Cursor position does not change.
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto i = begin(line);
    auto e = end(line);
    if(_mode == 0)
        i = std::min( i + m_PosX, e );
    else if(_mode == 1)
        e = std::min( i + m_PosX + 1, e );
    std::fill(i, e, m_EraseChar);
}

void Screen::EraseInLineCount(unsigned _n)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto i = std::begin(line) + m_PosX;
    auto e = std::min( i + _n, std::end(line) );
    std::fill(i, e, m_EraseChar);
}

void Screen::SetFgColor(int _color)
{
    m_EraseChar.foreground = _color;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetBgColor(int _color)
{
    m_EraseChar.background = _color;
    m_Buffer.SetEraseChar(m_EraseChar);    
}

void Screen::SetIntensity(bool _intensity)
{
    m_EraseChar.intensity = _intensity;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetUnderline(bool _is_underline)
{
    m_EraseChar.underline = _is_underline;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void Screen::SetReverse(bool _is_reverse)
{
    m_EraseChar.reverse = _is_reverse;
    m_Buffer.SetEraseChar(m_EraseChar);    
}

void Screen::SetAlternateScreen(bool _is_alternate)
{
    m_AlternateScreen = _is_alternate;
}

void Screen::DoShiftRowLeft(int _chars)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto chars = line.first;
    
    // TODO: write as an algo
    
    for(int x = m_PosX + _chars; x < Width(); ++x)
        chars[x-_chars] = chars[x];
    
    for(int i = 0; i < _chars; ++i)
        chars[Width()-i-1] = m_EraseChar; // why m_Width here???
    
}

void Screen::DoShiftRowRight(int _chars)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto chars = line.first;
    
    // TODO: write as an algo
    
    for(int x = Width()-1; x >= m_PosX + _chars; --x)
        chars[x] = chars[x - _chars];
    
    for(int i = 0; i < _chars; ++i)
        chars[m_PosX + i] = m_EraseChar;
}

void Screen::EraseAt(unsigned _x, unsigned _y, unsigned _count)
{
    if( auto line = m_Buffer.LineFromNo(_y) ) {
        auto i = std::begin(line) + _x;
        auto e = std::min( i + _count, std::end(line) );
        std::fill(i, e, m_EraseChar);
    }
}

void Screen::CopyLineChars(int _from, int _to)
{
    auto src = m_Buffer.LineFromNo(_from);
    auto dst = m_Buffer.LineFromNo(_to);
    if(src && dst)
        std::copy_n(begin(src),
                    std::min(std::end(src) - std::begin(src), std::end(dst) - std::begin(dst)),
                    std::begin(dst));
}

void Screen::ClearLine(int _ind)
{
    if( auto line = m_Buffer.LineFromNo(_ind) ) {
        std::fill( std::begin(line), std::end(line), m_EraseChar );
        m_Buffer.SetLineWrapped(_ind, false);
    }
}

void Screen::ScrollDown(const unsigned _top, const unsigned _bottom, const unsigned _lines)
{
    const auto top = (int)_top;
    const auto bottom = std::min((int)_bottom, Height());
    const auto lines = (int)_lines;
    if(top >= Height())
        return;
    if(top >= bottom)
        return;
    if(lines<1)
        return;
    
    for( int n_dst = bottom - 1, n_src = bottom - 1 - lines;
        n_dst > top && n_src >= top;
        --n_dst, --n_src) {
        CopyLineChars(n_src, n_dst);
        m_Buffer.SetLineWrapped(n_dst, m_Buffer.LineWrapped(n_src));        
    }
    
    for(int i = _top; i < std::min(top + lines, bottom); ++i)
        ClearLine(i);
}

void Screen::DoScrollUp(const unsigned _top, const unsigned _bottom, const unsigned _lines)
{
    const auto top = (int)_top;
    const auto bottom = std::min((int)_bottom, Height());
    const auto lines = (int)_lines;        
    if(top >= Height())
        return;
    if(top >= bottom)
        return;
    if(lines<1)
        return;

    if(top == 0 && bottom == Height() && !m_AlternateScreen)
        for(int i = 0; i < std::min(lines, Height()); ++i) {
            // we're scrolling up the whole screen - let's feed scrollback with leftover
            auto line = m_Buffer.LineFromNo(i);
            assert(line);
            m_Buffer.FeedBackscreen(begin(line),
                                    end(line),
                                    m_Buffer.LineWrapped(i));
        }
    
    for( int n_src = top + lines, n_dst = top;
        n_src < bottom && n_dst < bottom;
        ++n_src, ++n_dst ) {
        CopyLineChars(n_src, n_dst);
        m_Buffer.SetLineWrapped(n_dst, m_Buffer.LineWrapped(n_src));
    }
    
    for( int i = _bottom - 1; i >= std::max( (int)_bottom-(int)_lines, 0); --i)
        ClearLine(i);
}

void Screen::SaveScreen()
{
    m_Buffer.MakeSnapshot();
}

void Screen::RestoreScreen()
{
    m_Buffer.RevertToSnapshot();
}

void Screen::ResizeScreen(const unsigned _new_sx, const unsigned _new_sy)
{
    if(Width() == (int)_new_sx && Height() == (int)_new_sy)
        return;
    if( _new_sx == 0 || _new_sy == 0 )
        throw std::invalid_argument("Screen::ResizeScreen sizes can't be zero");
    
    bool feed_from_bs = m_PosY == Height() - 1; // questionable!
    
    m_Buffer.ResizeScreen(_new_sx, _new_sy, feed_from_bs && !m_AlternateScreen);
    
    // adjust cursor Y if it was at the bottom prior to resizing
    GoTo(CursorX(), feed_from_bs ? Height() - 1 : CursorY()); // will clip if necessary
}

void Screen::SetTitle(const char *_t)
{
    m_Title = _t;
}

void Screen::GoToDefaultPosition()
{
    GoTo(0, 0);
}

const std::string& Screen::Title() const
{
    return m_Title;
}

}
