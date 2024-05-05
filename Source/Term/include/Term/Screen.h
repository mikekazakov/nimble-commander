// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ScreenBuffer.h"
#include "ExtendedCharRegistry.h"
#include <mutex>

namespace nc::term {

class Screen
{
public:
    static const unsigned short MultiCellGlyph = ScreenBuffer::MultiCellGlyph;
    using Space = ScreenBuffer::Space;

    Screen(unsigned _width, unsigned _height, ExtendedCharRegistry &_reg = ExtendedCharRegistry::SharedInstance());

    std::unique_lock<std::mutex> AcquireLock() const noexcept;
    ScreenBuffer &Buffer() noexcept;
    const ScreenBuffer &Buffer() const noexcept;
    int Width() const noexcept;
    int Height() const noexcept;
    int CursorX() const noexcept;
    int CursorY() const noexcept;
    bool LineOverflown() const noexcept;

    void ResizeScreen(unsigned _new_sx, unsigned _new_sy);

    char32_t GetCh() noexcept;

    void PutCh(char32_t _char);

    /**
     * Marks current screen line as wrapped. That means that the next line is continuation of current line.
     */
    void PutWrap();

    void SetFgColor(std::optional<Color> _color);
    void SetBgColor(std::optional<Color> _color);
    void SetFaint(bool _faint);
    void SetUnderline(bool _is_underline);
    void SetCrossed(bool _is_crossed);
    void SetReverse(bool _is_reverse);
    void SetBold(bool _is_bold);
    void SetItalic(bool _is_italic);
    void SetInvisible(bool _is_invisible);
    void SetBlink(bool _is_blink);
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

    // CSI n J
    // ED – Erase Display    Clears part of the screen.
    //    If n is zero (or missing), clear from cursor to end of screen.
    //    If n is one, clear from cursor to beginning of the screen.
    //    If n is two, clear entire screen
    void DoEraseScreen(int _mode);

    // CSI n K
    // EL – Erase in Line    Erases part of the line.
    // If n is zero (or missing), clear from cursor to the end of the line.
    // If n is one, clear from cursor to beginning of the line.
    // If n is two, clear entire line.
    // Cursor position does not change.
    void EraseInLine(int _mode);

    // Erases _n characters in line starting from current cursor position. _n may be beyond bounds
    void EraseInLineCount(unsigned _n);

    void EraseAt(unsigned _x, unsigned _y, unsigned _count);

    void FillScreenWithSpace(ScreenBuffer::Space _space);

    void DoShiftRowLeft(int _chars);
    void DoShiftRowRight(int _chars);

    void SetVideoReverse(bool _reverse) noexcept;
    bool VideoReverse() const noexcept;

private:
    struct SavedScreen {
        ScreenBuffer::Snapshot snapshot;
        int pos_x = 0;
        int pos_y = 0;
    };

    void CopyLineChars(int _from, int _to);
    void ClearLine(int _ind);
    SavedScreen CaptureScreen() const;

    mutable std::mutex m_Lock;
    const ExtendedCharRegistry &m_Registry;
    int m_PosX = 0;
    int m_PosY = 0;
    Space m_EraseChar = ScreenBuffer::DefaultEraseChar();
    ScreenBuffer m_Buffer;
    bool m_AlternateScreen = false;
    bool m_LineOverflown = false;
    bool m_ReverseVideo = false;
    SavedScreen m_PrimaryScreenshot;
    SavedScreen m_AlternativeScreenshot;
};

} // namespace nc::term
