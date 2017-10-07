#pragma once

#include "CursorMode.h"

#ifdef __OBJC__
@class NSFont;
@class NSColor;
#else 
using NSFont = void*;
using NSColor = void*;
#endif

namespace nc::term {

class Settings
{
public:
    virtual NSFont  *Font() const = 0;
    virtual NSColor *ForegroundColor() const = 0;
    virtual NSColor *BoldForegroundColor() const = 0;
    virtual NSColor *BackgroundColor() const = 0;
    virtual NSColor *SelectionColor() const = 0;
    virtual NSColor *CursorColor() const = 0;
    virtual NSColor *AnsiColor0() const = 0;
    virtual NSColor *AnsiColor1() const = 0;
    virtual NSColor *AnsiColor2() const = 0;
    virtual NSColor *AnsiColor3() const = 0;
    virtual NSColor *AnsiColor4() const = 0;
    virtual NSColor *AnsiColor5() const = 0;
    virtual NSColor *AnsiColor6() const = 0;
    virtual NSColor *AnsiColor7() const = 0;
    virtual NSColor *AnsiColor8() const = 0;
    virtual NSColor *AnsiColor9() const = 0;
    virtual NSColor *AnsiColorA() const = 0;
    virtual NSColor *AnsiColorB() const = 0;
    virtual NSColor *AnsiColorC() const = 0;
    virtual NSColor *AnsiColorD() const = 0;
    virtual NSColor *AnsiColorE() const = 0;
    virtual NSColor *AnsiColorF() const = 0;
    virtual int MaxFPS() const = 0;
    virtual enum CursorMode CursorMode() const = 0;
    
    // observe changes
    
    
};

//    static const auto g_ConfigHideScrollbar = "terminal.hideVerticalScrollbar";
//    static const auto g_UseDefault = "terminal.useDefaultLoginShell";
//    static const auto g_CustomPath = "terminal.customShellPath";
//    static const auto g_ConfigMaxFPS = "terminal.maxFPS";
//    static const auto g_ConfigCursorMode = "terminal.cursorMode";

//    
//    NSFont  *TerminalFont() const noexcept;
//    NSColor *TerminalOverlayColor() const noexcept;
//    NSColor *TerminalForegroundColor() const noexcept;
//    NSColor *TerminalBoldForegroundColor() const noexcept;
//    NSColor *TerminalBackgroundColor() const noexcept;
//    NSColor *TerminalSelectionColor() const noexcept;
//    NSColor *TerminalCursorColor() const noexcept;
//    NSColor *TerminalAnsiColor0() const noexcept;
//    NSColor *TerminalAnsiColor1() const noexcept;
//    NSColor *TerminalAnsiColor2() const noexcept;
//    NSColor *TerminalAnsiColor3() const noexcept;
//    NSColor *TerminalAnsiColor4() const noexcept;
//    NSColor *TerminalAnsiColor5() const noexcept;
//    NSColor *TerminalAnsiColor6() const noexcept;
//    NSColor *TerminalAnsiColor7() const noexcept;
//    NSColor *TerminalAnsiColor8() const noexcept;
//    NSColor *TerminalAnsiColor9() const noexcept;
//    NSColor *TerminalAnsiColorA() const noexcept;
//    NSColor *TerminalAnsiColorB() const noexcept;
//    NSColor *TerminalAnsiColorC() const noexcept;
//    NSColor *TerminalAnsiColorD() const noexcept;
//    NSColor *TerminalAnsiColorE() const noexcept;
//    NSColor *TerminalAnsiColorF() const noexcept;
//    
    
}

