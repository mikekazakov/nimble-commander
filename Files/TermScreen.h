//
//  TermScreen.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <list>
#include <vector>
#include <mutex>

struct TermScreenColors
{
    enum {
        Black       = 0,
        Red         = 1,
        Green       = 2,
        Yellow      = 3,
        Blue        = 4,
        Magenta     = 5,
        Cyan        = 6,
        White       = 7,
        BlackHi     = 8,
        RedHi       = 9,
        GreenHi     = 10,
        YellowHi    = 11,
        BlueHi      = 12,
        MagentaHi   = 13,
        CyanHi      = 14,
        WhiteHi     = 15
    };
};

class TermScreen
{
public:
    TermScreen(int _w, int _h);
    ~TermScreen();

    static const unsigned short MultiCellGlyph = 0xFFFE;
    
    struct Space
    {
        unsigned short l; // letter. consider UTF-32 here? (16bit is not enough)
        unsigned int foreground :3;
        unsigned int background :3;
        unsigned int intensity  :1;
        unsigned int underline  :1;
        unsigned int reverse    :1;
    };
    
    struct ScreenShot // allocated with malloc, line by line from [0] till [height-1]
    {
        int width;
        int height;
        Space chars[1]; // chars will be a real size
        static inline size_t sizefor(int _sx, int _sy) { return sizeof(int)*2 + sizeof(Space)*_sx*_sy; }
    };
    
    inline void Lock()      { m_Lock.lock();   }
    inline void Unlock()    { m_Lock.unlock(); }
    
//    int GetLinesCount() const;
    const std::vector<Space> *GetScreenLine(int _line_no) const;
    const std::vector<Space> *GetScrollBackLine(int _line_no) const;
    
    inline int ScrollBackLinesCount() const { return (int)m_ScrollBack.size(); }
    
    void ResizeScreen(int _new_sx, int _new_sy);
    
    void PutCh(unsigned short _char);
    void SetColor(unsigned char _color);
    void SetIntensity(unsigned char _intensity);
    void SetUnderline(bool _is_underline);
    void SetReverse(bool _is_reverse);

    void GoTo(int _x, int _y);
    void DoCursorUp(int _n = 1);
    void DoCursorDown(int _n = 1);
    void DoCursorLeft(int _n = 1);
    void DoCursorRight(int _n = 1);
    void DoEraseCharacters(int _n);
    
    void DoScrollDown(int _top, int _bottom, int _lines);
    void DoScrollUp(int _top, int _bottom, int _lines);
    
    void SaveScreen();
    void RestoreScreen();
    
    
    inline int Width()   const { return m_Width;  }
    inline int Height()  const { return m_Height; }
    inline int CursorX() const { return m_PosX;   }
    inline int CursorY() const { return m_PosY;   }
    
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
// If n is two, clear entire line. Cursor position does not change.
    void DoEraseInLine(int _mode);
    
    
    void DoShiftRowLeft(int _chars);
    
    inline void SetTitle(const char *_t) { strcpy(m_Title, _t); }
    inline const char* Title() const { return m_Title; }
    
private:
    static const int        m_TitleMaxLen = 1024;
    char                    m_Title[m_TitleMaxLen];
    
    std::mutex      m_Lock;
    unsigned char m_Color;
    
    unsigned char m_Intensity;
    bool          m_Underline;
    bool          m_Reverse;
    int m_Width;
    int m_Height;
    int m_PosX;
    int m_PosY;
    Space m_EraseChar;
    
    ScreenShot *m_ScreenShot;
    
    std::vector<Space> *GetLineRW(int _line_no);
    
    std::list<std::vector<Space>> m_Screen;
    std::list<std::vector<Space>> m_ScrollBack;
    
};
