// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ScreenBuffer.h"
#include <mutex>

namespace nc::term {

class Screen
{
public:
    static const unsigned short MultiCellGlyph = ScreenBuffer::MultiCellGlyph;
    using Space = ScreenBuffer::Space;
    
    Screen(unsigned _width, unsigned _height);
    
    std::unique_lock<std::mutex>    AcquireLock()    const { return std::unique_lock{m_Lock}; }
    inline const ScreenBuffer      &Buffer()  const { return m_Buffer;          }
    inline int                      Width()   const { return m_Buffer.Width();  }
    inline int                      Height()  const { return m_Buffer.Height(); }
    inline int                      CursorX() const { return m_PosX;            }
    inline int                      CursorY() const { return m_PosY;            }
    
    void ResizeScreen(unsigned _new_sx, unsigned _new_sy);
    
    void PutCh(uint32_t _char);
    void PutString(const std::string &_str);
    
    /**
     * Marks current screen line as wrapped. That means that the next line is continuation of current line.
     */
    void PutWrap();
    
    void SetFgColor(int _color);
    void SetBgColor(int _color);
    void SetIntensity(bool _intensity);
    void SetUnderline(bool _is_underline);
    void SetReverse(bool _is_reverse);
    void SetAlternateScreen(bool _is_alternate);

    void GoTo(int _x, int _y);
    void GoToDefaultPosition();
    void DoCursorUp(int _n = 1);
    void DoCursorDown(int _n = 1);
    void DoCursorLeft(int _n = 1);
    void DoCursorRight(int _n = 1);
    
    /**
     *
     * _lines - amount of lines to scroll by
     */
    void ScrollDown(unsigned _top, unsigned _bottom, unsigned _lines);
    void DoScrollUp(unsigned _top, unsigned _bottom, unsigned _lines);
    
    void SaveScreen();
    void RestoreScreen();
    
// CSI n J
// ED – Erase Display	Clears part of the screen.
//    If n is zero (or missing), clear from cursor to end of screen.
//    If n is one, clear from cursor to beginning of the screen.
//    If n is two, clear entire screen
    void DoEraseScreen(int _mode);

// CSI n K
// EL – Erase in Line	Erases part of the line.
// If n is zero (or missing), clear from cursor to the end of the line.
// If n is one, clear from cursor to beginning of the line.
// If n is two, clear entire line.
// Cursor position does not change.
    void EraseInLine(int _mode);
    
    // Erases _n characters in line starting from current cursor position. _n may be beyond bounds
    void EraseInLineCount(unsigned _n);
    
    void EraseAt(unsigned _x, unsigned _y, unsigned _count);
    
    
    void DoShiftRowLeft(int _chars);
    void DoShiftRowRight(int _chars);    
    
    void SetTitle(const char *_t);
    const std::string& Title() const;
    
private:
    void CopyLineChars(int _from, int _to);
    void ClearLine(int _ind);
    
    mutable std::mutex            m_Lock;
    int                           m_PosX = 0;
    int                           m_PosY = 0;
    Space                         m_EraseChar = ScreenBuffer::DefaultEraseChar();
    ScreenBuffer                  m_Buffer;
    std::string                   m_Title;
    bool                          m_AlternateScreen = false;
};

}
