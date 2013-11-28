//
//  TermScreen.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <algorithm>
#include <stdio.h>
#include <assert.h>

#include "TermScreen.h"
#include "FontCache.h"

TermScreen::TermScreen(int _w, int _h):
    m_Width(_w),
    m_Height(_h),
    m_PosX(0),
    m_PosY(0),
    m_Color(0x7),
    m_Intensity(0),
    m_Underline(false),
    m_ScreenShot(0)
{
    m_EraseChar.l = 0;
    m_EraseChar.foreground = 0x7;
    m_EraseChar.background = 0;
    m_EraseChar.intensity = 0;
    m_EraseChar.underline = 0;
    
    m_Title[0] = 0;
    
    for(int i =0; i < m_Height; ++i)
    {
        m_Screen.push_back(std::vector<TermScreen::Space>());
        std::vector<TermScreen::Space> *line = &m_Screen.back();
        line->resize(m_Width, m_EraseChar);
    }
}

TermScreen::~TermScreen()
{
    /* MANY STUFF HERE ! */
}

const std::vector<TermScreen::Space> *TermScreen::GetScreenLine(int _line_no) const
{
    if(_line_no >= m_Screen.size()) return 0;
    
    auto it = m_Screen.begin();
    for(int i = 0; i < _line_no; ++i)
        ++it;
  
    return &(*it);
}

std::vector<TermScreen::Space> *TermScreen::GetLineRW(int _line_no)
{
    if(_line_no >= m_Screen.size()) return 0;
    
    auto it = m_Screen.begin();
    for(int i = 0; i < _line_no; ++i)
        ++it;
    
    return &(*it);
}

void TermScreen::PutCh(unsigned short _char)
{
    assert(m_PosY < m_Screen.size());
    assert(m_PosX >= 0 && m_PosX < m_Width);
    // TODO: optimize it out
    
    auto it = m_Screen.begin();
    for(int i = 0; i < m_PosY; ++i) ++it;
    std::vector<TermScreen::Space> *line = &(*it);
    auto &sp = (*line)[m_PosX++];
    
    sp.l = _char;
    sp.foreground = m_Color & 0x7;
    sp.background = (m_Color & 0x38) >> 3;
    sp.intensity = m_Intensity;
    sp.underline = m_Underline;
    
    if(g_WCWidthTableFixedMin1[_char] == 2 && m_PosX < m_Width)
    {
        auto &foll = (*line)[m_PosX++];
        foll = sp;
        foll.l = MultiCellGlyph;
    }
}

// ED – Erase Display	Clears part of the screen.
//    If n is zero (or missing), clear from cursor to end of screen.
//    If n is one, clear from cursor to beginning of the screen.
//    If n is two, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS).
void TermScreen::DoEraseScreen(int _mode)
{
    if(_mode == 1) {
        for(int i = 0; i < m_Height; ++i) {
            auto *l = GetLineRW(i);
            for(int j = 0; j < m_Width; ++j) {
                (*l)[j] = m_EraseChar;
                if(i == m_PosY && j == m_PosX)
                    return;
            }
        }
    } else if(_mode == 2)
    { // clear all screen
        for(auto &l: m_Screen)
            for(int i =0; i < l.size(); ++i)
                l[i] = m_EraseChar;
        
//        GoTo(0, 0);
    } else {
        for(int i = m_PosY; i < m_Height; ++i) {
            auto *l = GetLineRW(i);
            for(int j = (i == m_PosY ? m_PosX : 0); j < m_Width; ++j)
                (*l)[j] = m_EraseChar;
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
        for(int i = 0; i < line->size() && i <= m_PosX; ++i)
            (*line)[i] = m_EraseChar;
    }
    else if(_mode == 2) {
        for(int i = 0; i < line->size(); ++i)
            (*line)[i] = m_EraseChar;
    }
    else {
        for(int i = m_PosX; i < line->size(); ++i)
            (*line)[i] = m_EraseChar;
    }
}

void TermScreen::DoEraseCharacters(int _n)
{
    auto *line = GetLineRW(m_PosY);
    if(!line)
        return;
    for(int i = m_PosX; i < line->size() && _n > 0; ++i, --_n)
        (*line)[i] = m_EraseChar;
}

void TermScreen::SetColor(unsigned char _color)
{
    m_Color = _color;
    m_EraseChar.foreground = m_Color & 0x7;
    m_EraseChar.background = (m_Color & 0x38) >> 3;
}

void TermScreen::SetIntensity(unsigned char _intensity)
{
    m_Intensity = _intensity;
    m_EraseChar.intensity = m_Intensity;
}

void TermScreen::SetUnderline(bool _is_underline)
{
    m_Underline = _is_underline;
    m_EraseChar.underline = _is_underline;
}

void TermScreen::DoShiftRowLeft(int _chars)
{
    auto *line = GetLineRW(m_PosY);
    if(!line)
        return;
    
    for(int x = m_PosX + _chars; x < m_Width; ++x)
        if(x-_chars >= 0)
            (*line)[x-_chars] = (*line)[x];
    
    for(int i = 0; i < _chars; ++i)
        (*line)[m_Width-i-1] = m_EraseChar;
}

void TermScreen::DoScrollDown(int _top, int _bottom, int _lines)
{
    /*
     #define scrdown(foo,t,b,nr) do { \
        unsigned int step; \
        int scrdown_nr=nr; \
        \
        if (t+scrdown_nr >= b) \
            scrdown_nr = b - t - 1; \
        if (b > height || t >= b || scrdown_nr < 1) \
        return; \
        step = width * scrdown_nr; \
        [ts ts_scrollDown: t:b  rows: scrdown_nr]; \
        [ts ts_putChar: video_erase_char  count: step  offset: t*width]; \
     } while (0)
     */
    
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
        for(int j = 0; j < m_Width; ++j)
            (*line)[j] = m_EraseChar;
    }
}

void TermScreen::DoScrollUp(int _top, int _bottom, int _lines)
{
    /*
     scrup(foo,top,bottom,1,(top==0 && bottom==height)?YES:NO);
     #define scrup(foo,t,b,nr,indirect_scroll) do { \
        int scrup_nr=nr; \
     \
        if (t+scrup_nr >= b) \
            scrup_nr = b - t - 1; \
        if (b > height || t >= b || scrup_nr < 1) \
            return; \
        [ts ts_scrollUp: t:b  rows: scrup_nr  save: indirect_scroll]; \
        [ts ts_putChar: video_erase_char  count: width*scrup_nr  offset: width*(b-scrup_nr)]; \
     } while (0)
     */
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
            // TODO: optimize this on speed and possible memory consumpion
            auto *src = GetLineRW(i);
            assert(src);
            m_ScrollBack.push_back(*src);
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
        for(int j = 0; j < m_Width; ++j)
            (*line)[j] = m_EraseChar;
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
        for(auto j: i)
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
            i[x] = m_ScreenShot->chars[y*m_ScreenShot->width + x];
        
        ++y;
    }
    
    free(m_ScreenShot);
    m_ScreenShot = 0;
}

const std::vector<TermScreen::Space> *TermScreen::GetScrollBackLine(int _line_no) const
{
    if(_line_no >= m_ScrollBack.size()) return 0;
    
    auto it = m_ScrollBack.begin();
    for(int i = 0; i < _line_no; ++i)
        ++it;
    
    return &(*it);    
}
