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
#include <pthread.h>

/*
Intensity	0	1	2	3	4	5	6	7
Normal	Black	Red	Green	Yellow[11]	Blue	Magenta	Cyan	White
Bright	Black	Red	Green	Yellow	Blue	Magenta	Cyan	White
*/
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

    struct Space
    {
        unsigned short l; // letter. consider UTF-32 here? (16bit is not enough)
        unsigned int foreground :3;
        unsigned int background :3;
        unsigned int intensity  :1;
        unsigned int underline  :1;
    };
    
    struct ScreenShot // allocated with malloc, line by line from [0] till [height-1]
    {
        int width;
        int height;
        Space chars[1]; // chars will be a real size
        static inline size_t sizefor(int _sx, int _sy) { return sizeof(int)*2 + sizeof(Space)*_sx*_sy; }
    };
    
    void Lock();
    void Unlock();
    
    int GetLinesCount() const;
    const std::vector<Space> *GetLine(int _line_no) const;
    
    void PutCh(unsigned short _char);
    void SetColor(unsigned char _color);
    void SetIntensity(unsigned char _intensity);
    void SetUnderline(bool _is_underline);
    
    
    void PrintToConsole();
    

    void GoTo(int _x, int _y);
    void DoCursorUp(int _n = 1);
    void DoCursorDown(int _n = 1);
    void DoCursorLeft(int _n = 1);
    void DoCursorRight(int _n = 1);
//    void DoLineFeed();
//    void DoCarriageReturn();
    void DoEraseCharacters(int _n);
    
    void DoScrollDown(int _top, int _bottom, int _lines);
    void DoScrollUp(int _top, int _bottom, int _lines);
    
    void SaveScreen();
    void RestoreScreen();
    
    
    inline int GetWidth()   const { return m_Width;  }
    inline int GetHeight()  const { return m_Height; }
    inline int GetCursorX() const { return m_PosX;   }
    inline int GetCursorY() const { return m_PosY;   }
    
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
    
    pthread_mutex_t m_Lock;
    unsigned char m_Color;
    
    unsigned char m_Intensity;
    bool          m_Underline;
    int m_Width;
    int m_Height;
    int m_PosX;
    int m_PosY;
    Space m_EraseChar;
    
    ScreenShot *m_ScreenShot;
    
    std::vector<Space> *AddNewLine();
    void ScrollBufferUp();
    std::vector<Space> *GetLineRW(int _line_no);
    
    std::list<std::vector<Space>> m_Chars;
};
