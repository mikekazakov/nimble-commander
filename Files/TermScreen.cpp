//
//  TermScreen.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "TermScreen.h"
#include "FontCache.h"
#include "OrthodoxMonospace.h"

unsigned TermScreen::Line::actual_length() const
{
    size_t len = 0, i = 0, e = chars.size();
    for(;i!=e;++i)
        if(chars[i].l != 0)
            len = i+1;
    return (unsigned)len;
}

TermScreen::TermScreen(int _w, int _h):
    m_Width(_w),
    m_Height(_h)
{
    m_EraseChar.l = 0;
    m_EraseChar.c1 = 0;
    m_EraseChar.c2 = 0;
    m_EraseChar.foreground = TermScreenColors::Default;
    m_EraseChar.background = TermScreenColors::Default;
    m_EraseChar.intensity = 0;
    m_EraseChar.underline = 0;
    m_EraseChar.reverse   = 0;
    
    m_Title[0] = 0;
    
    Line l;
    l.chars.resize(m_Width, m_EraseChar);
    for(int i =0; i < m_Height; ++i)
        m_Screen.push_back(l);
}

TermScreen::~TermScreen()
{
    free(m_ScreenShot);
}

const TermScreen::Line *TermScreen::GetScreenLine(int _line_no) const
{
    if(_line_no < 0 || _line_no >= m_Screen.size()) return nullptr;
    
    auto it = begin(m_Screen);
    advance(it, _line_no);
  
    return &(*it);
}

TermScreen::Line *TermScreen::GetLineRW(int _line_no)
{
    if(_line_no < 0 || _line_no >= m_Screen.size()) return nullptr;
    
    auto it = begin(m_Screen);
    advance(it, _line_no);
    
    return &(*it);
}

void TermScreen::PutCh(uint32_t _char)
{
    assert(m_PosY < m_Screen.size());
    // TODO: optimize it out
    
    auto &line = *GetLineRW(m_PosY);
    
    if(!oms::IsUnicodeCombiningCharacter(_char))
    {
        assert(m_PosX >= 0 && m_PosX < m_Width);
        auto &sp = line.chars[m_PosX++];
        sp.l = _char;
        sp.c1 = 0;
        sp.c2 = 0;
        sp.foreground = m_ForegroundColor;
        sp.background = m_BackgroundColor;
        sp.intensity = m_Intensity;
        sp.underline = m_Underline;
        sp.reverse   = m_Reverse;
    
        if(oms::WCWidthMin1(_char) == 2 && m_PosX < m_Width)
        {
            auto &foll = line.chars[m_PosX++];
            foll = sp;
            foll.l = MultiCellGlyph;
        }
    }
    else
    { // combining characters goes here
        if(m_PosX > 0)
        {
            assert(m_PosX <= m_Width);
            int target_pos = m_PosX - 1;
            if((line.chars[target_pos].l == MultiCellGlyph) && (target_pos > 0)) target_pos--;
            if(line.chars[target_pos].c1 == 0) line.chars[target_pos].c1 = _char;
            else if(line.chars[target_pos].c2 == 0) line.chars[target_pos].c2 = _char;
        }
    }
    
    line.wrapped = false;
}

void TermScreen::PutWrap()
{
    // TODO: optimize it out
    assert(m_PosY < m_Screen.size());
    GetLineRW(m_PosY)->wrapped = true;
}

// ED – Erase Display	Clears part of the screen.
//    If n is zero (or missing), clear from cursor to end of screen.
//    If n is one, clear from beginning of the screen to cursor.
//    If n is two, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS).
void TermScreen::DoEraseScreen(int _mode)
{
    if(_mode == 1) {
        for(int i = 0; i < m_Height; ++i) {
            auto &l = *GetLineRW(i);
            for(int j = 0; j < m_Width; ++j) {
                l.chars[j] = m_EraseChar;
                if(i == m_PosY && j == m_PosX)
                    return;
            }
            l.wrapped = false;
        }
    } else if(_mode == 2)
    { // clear all screen
        for(auto &l: m_Screen) {
            l.wrapped = false;
            for(auto &c: l.chars)
                c = m_EraseChar;
        }
    } else {
        for(int i = m_PosY; i < m_Height; ++i) {
            auto &l = *GetLineRW(i);
            l.wrapped = false;
            for(int j = (i == m_PosY ? m_PosX : 0); j < m_Width; ++j)
                l.chars[j] = m_EraseChar;
        }
    }
}

void TermScreen::GoTo(int _x, int _y)
{
    // any cursor movement which change Y should end here!
    
    m_PosX = _x;
    m_PosY = _y;
    if(m_PosX < 0) m_PosX = 0;
    if(m_PosX >= m_Width) m_PosX = m_Width - 1;
    if(m_PosY < 0) m_PosY = 0;
    if(m_PosY >= m_Height) m_PosY = m_Height - 1;
}

void TermScreen::DoCursorUp(int _n)
{
    GoTo(m_PosX, m_PosY-_n);
}

void TermScreen::DoCursorDown(int _n)
{
    GoTo(m_PosX, m_PosY+_n);
}

void TermScreen::DoCursorLeft(int _n)
{
    GoTo(m_PosX-_n, m_PosY);
}

void TermScreen::DoCursorRight(int _n)
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

void TermScreen::DoEraseInLine(int _mode)
{
    // If n is zero (or missing), clear from cursor to the end of the line.
    // If n is one, clear from cursor to beginning of the line.
    // If n is two, clear entire line. Cursor position does not change.
    auto *line = GetLineRW(m_PosY);
    if(!line)
        return;
    if(_mode == 1) {
        for(int i = 0; i < line->chars.size() && i <= m_PosX; ++i)
            line->chars[i] = m_EraseChar;
    }
    else if(_mode == 2) {
        for(int i = 0; i < line->chars.size(); ++i)
            line->chars[i] = m_EraseChar;
    }
    else {
        for(int i = m_PosX; i < line->chars.size(); ++i)
            line->chars[i] = m_EraseChar;
    }
}

void TermScreen::DoEraseCharacters(int _n)
{
    auto *line = GetLineRW(m_PosY);
    if(!line)
        return;
    for(int i = m_PosX; i < line->chars.size() && _n > 0; ++i, --_n)
        line->chars[i] = m_EraseChar;
}

void TermScreen::SetFgColor(int _color)
{
    m_ForegroundColor = _color;
    m_EraseChar.foreground = _color;
}

void TermScreen::SetBgColor(int _color)
{
    m_BackgroundColor = _color;
    m_EraseChar.background = _color;
}

void TermScreen::SetIntensity(bool _intensity)
{
    m_Intensity = _intensity;
    m_EraseChar.intensity = m_Intensity;
}

void TermScreen::SetUnderline(bool _is_underline)
{
    m_Underline = _is_underline;
    m_EraseChar.underline = _is_underline;
}

void TermScreen::SetReverse(bool _is_reverse)
{
    m_Reverse = _is_reverse;
    m_EraseChar.reverse = _is_reverse;
}

void TermScreen::SetAlternateScreen(bool _is_alternate)
{
    m_AlternateScreen = _is_alternate;
}

void TermScreen::DoShiftRowLeft(int _chars)
{
    auto *line = GetLineRW(m_PosY);
    if(!line)
        return;
    
    assert(m_PosX >= 0 && m_PosX < m_Width);
    
    for(int x = m_PosX + _chars; x < m_Width; ++x)
//        if(x-_chars >= 0)
            line->chars[x-_chars] = line->chars[x];
    
    for(int i = 0; i < _chars; ++i)
        line->chars[m_Width-i-1] = m_EraseChar; // why m_Width here???
}

void TermScreen::DoShiftRowRight(int _chars)
{
    auto *line = GetLineRW(m_PosY);
    if(!line)
        return;

    assert(m_PosX >= 0 && m_PosX < m_Width);
    
    for(int x = m_Width-1; x >= m_PosX + _chars; --x)
        line->chars[x] = line->chars[x - _chars];
        
    for(int i = 0; i < _chars; ++i)
        line->chars[m_PosX + i] = m_EraseChar;
}

void TermScreen::DoEraseAt(int _x, int _y, int _count)
{    
    auto *line = GetLineRW(_y);
    if(!line)
        return;
    
    for(int i = _x; i < _x + _count && i > 0 && i < m_Width; ++i)
        line->chars[i] = m_EraseChar;
}

void TermScreen::DoScrollDown(int _top, int _bottom, int _lines)
{
    if(_top < 0)
        _top = 0;
    if(_bottom > m_Height)
        _bottom = m_Height;
    
    if(_top + _lines >= _bottom)
        _lines = _bottom - _top - 1;
    
    for(int i = _bottom-1; i - _lines >= _top; --i)
    {
        auto *src = GetLineRW(i - _lines);
        auto *dst = GetLineRW(i);
        assert(src && dst);
        
        *dst = *src;
    }
        
    for(int i = _top; i < _top + _lines; ++i)
    {
        auto *line = GetLineRW(i);
        assert(line);
        for(auto &c: line->chars)
            c = m_EraseChar;
    }
}

void TermScreen::DoScrollUp(int _top, int _bottom, int _lines)
{
    if(_top < 0)
        _top = 0;
    if(_bottom > m_Height)
        _bottom = m_Height;
    
    if(_top + _lines >= _bottom)
        _lines = _bottom - _top - 1;

    if(_lines < 1)
        return;

    if(_top == 0 && _bottom == m_Height)
        for(int i = 0; i < _lines; ++i)
        { // we're scrolling up the whole screen - let's feed scrollback with leftover
            m_ScrollBack.emplace_back(*GetLineRW(i));
            m_ScrollBack.back().chars.resize(m_ScrollBack.back().actual_length());
        }
    
    for(int i = _top; i < _bottom - _lines; ++i)
    {
        auto *src = GetLineRW(i + _lines);
        auto *dst = GetLineRW(i);
        assert(src && dst);
        
        *dst = *src;
    }
    
    for(int i = _bottom - 1; i >= _bottom - _lines; --i)
    {
        auto *line = GetLineRW(i);
        assert(line);
        for(auto &c: line->chars)
            c = m_EraseChar;
        line->wrapped = false;
    }
}

void TermScreen::SaveScreen()
{
    if(m_ScreenShot)
        return;
    free(m_ScreenShot);

    m_ScreenShot = (ScreenShot*) malloc(ScreenShot::sizefor(m_Width, m_Height));
    m_ScreenShot->width = m_Width;
    m_ScreenShot->height = m_Height;
    int y = 0;
    for(auto &i: m_Screen)
    {
        int x = 0;
        for(auto j: i.chars)
            m_ScreenShot->chars[y*m_Width + x++] = j;
        ++y;
    }
}

void TermScreen::RestoreScreen()
{
    if(!m_ScreenShot)
        return;
    
    int y = 0;
    int xmax = m_Width > m_ScreenShot->width ? m_ScreenShot->width : m_Width;
    for(auto &i: m_Screen)
    {
        if(y >= m_ScreenShot->height)
            break;
        
        for(int x = 0; x < xmax; ++x)
            i.chars[x] = m_ScreenShot->chars[y*m_ScreenShot->width + x];
        
        ++y;
    }
    
    free(m_ScreenShot);
    m_ScreenShot = 0;
}

const TermScreen::Line *TermScreen::GetScrollBackLine(int _line_no) const
{
    if(_line_no < 0 || _line_no >= m_ScrollBack.size()) return 0;
    
    auto it = m_ScrollBack.begin();
    advance(it, _line_no);    
    return &(*it);    
}

void TermScreen::ResizeScreen(int _new_sx, int _new_sy)
{
    if(m_Width == _new_sx && m_Height == _new_sy)
        return;
        
    Lock();

    list<TermScreen::Line> new_screen, new_scrollback;
    bool feed_from_bs = m_PosY == m_Height - 1; // questionable!
    
    // if we're on alternate screen (ie mc, man, top etc) - don't alter backscroll on resizing side-effects
    
    if(feed_from_bs && !m_AlternateScreen) {
        // compose non-wrapped strings from current screen and backscroll
        auto comp_lines = ComposeContinuousLines(m_ScrollBack, m_Screen);

        // decompose it back with new width
        auto new_lines = DecomposeContinuousLines(comp_lines, _new_sx);
        if(new_lines.size() <= _new_sy)
            new_screen = move(new_lines);
        else {
            auto it = end(new_lines);
            advance(it, -_new_sy);
            new_screen.splice(end(new_screen), new_lines, it, end(new_lines));
            new_scrollback = move(new_lines);
        }
    } else {
        // compose non-wrapped strings from current screen
        auto comp_lines = ComposeContinuousLines(m_Screen);
        
        // decompose it back with new width
        auto new_lines = DecomposeContinuousLines(comp_lines, _new_sx);

        new_scrollback = DecomposeContinuousLines(ComposeContinuousLines(m_ScrollBack), _new_sx);
        
        if(new_lines.size() <= _new_sy || m_AlternateScreen)
            new_screen = move(new_lines);
        else {
            auto it = end(new_lines);
            advance(it, -_new_sy);
            new_screen.splice(end(new_screen), new_lines, it, end(new_lines));
            new_scrollback.splice(end(new_scrollback), new_lines, begin(new_lines), end(new_lines));
        }
    }
    
    // 3rd - append height if need
    new_screen.resize(_new_sy);

    // fill gaps(if any) with m_EraseChar
    for(auto &l: new_screen)
        l.chars.resize(_new_sx, m_EraseChar);
    
    m_Screen = move(new_screen);
    m_ScrollBack = move(new_scrollback);
    
    m_Height = _new_sy;
    m_Width = _new_sx;
    
    if(m_ScreenShot != 0)
    { // resize alternative screen
        ScreenShot *old = m_ScreenShot;
        m_ScreenShot = (ScreenShot*) malloc(ScreenShot::sizefor(m_Width, m_Height));
        m_ScreenShot->width = m_Width;
        m_ScreenShot->height = m_Height;

        for(int i = 0; i < m_Width*m_Height; ++i)
            m_ScreenShot->chars[i] = m_EraseChar;
        
        for(int y = 0; y < m_ScreenShot->height && y < old->height; ++y)
            for(int x = 0; x < m_ScreenShot->width && x < old->width; ++x)
                m_ScreenShot->chars[ y*m_ScreenShot->width + x ] = old->chars[ y*old->width + x ];
        
        free(old);
    }

    // adjust cursor Y if it was at the bottom prior to resizing
    GoTo(CursorX(), feed_from_bs ? m_Height - 1 : CursorY()); // will clip if necessary
    
    Unlock();
}

list<vector<TermScreen::Space>> TermScreen::ComposeContinuousLines(const list<Line> &_from)
{
    list<vector<TermScreen::Space>> lines;
    vector<TermScreen::Space> *curr = nullptr;
    
    bool cont = false;
    for(auto &l: _from) {
        if(!cont) {
            lines.emplace_back();
            curr = &lines.back();
        }
        
        curr->insert(end(*curr),
                     begin(l.chars),
                     begin(l.chars) + l.actual_length());
        
        cont = l.wrapped;
    }
    return lines;
}

list<vector<TermScreen::Space>> TermScreen::ComposeContinuousLines(const list<Line> &_from1, const list<Line> &_from2)
{
    list<vector<TermScreen::Space>> lines;
    vector<TermScreen::Space> *curr = nullptr;
    
    bool cont = false;
    for(auto &l: _from1) {
        if(!cont) {
            lines.emplace_back();
            curr = &lines.back();
        }
        
        curr->insert(end(*curr),
                     begin(l.chars),
                     begin(l.chars) + l.actual_length());
        
        cont = l.wrapped;
    }
    
    for(auto &l: _from2) {
        if(!cont) {
            lines.emplace_back();
            curr = &lines.back();
        }
        
        curr->insert(end(*curr),
                     begin(l.chars),
                     begin(l.chars) + l.actual_length());
        
        cont = l.wrapped;
    }
    
    return lines;
}

list<TermScreen::Line> TermScreen::DecomposeContinuousLines(const list<vector<Space>> &_from, unsigned _width)
{
    list<TermScreen::Line> lines;
    for(auto &l: _from) {
        if(l.empty()) // special case for CRLF-only lines
            lines.emplace_back();
        
        for(int i = 0; i < l.size(); i += _width) {
            lines.emplace_back();
            auto &dl = lines.back();
            if(i + _width < l.size()) {
                dl.chars.assign(begin(l) + i, begin(l) + i + _width);
                dl.wrapped = true;
            }
            else
                dl.chars.assign(begin(l) + i, l.end());
        }
    }
    return lines;
}
