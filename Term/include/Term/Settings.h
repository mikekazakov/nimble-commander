// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "CursorMode.h"
#include <functional>

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
    virtual ~Settings() = 0;
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
    virtual bool HideScrollbar() const = 0;
    
    virtual int StartChangesObserving( std::function<void()> _callback ) = 0;
    virtual void StopChangesObserving( int _ticket ) = 0;
};


class DefaultSettings : public Settings
{
public:
    static std::shared_ptr<Settings> SharedDefaultSettings();
    NSFont  *Font() const override;
    NSColor *ForegroundColor() const override;
    NSColor *BoldForegroundColor() const override;
    NSColor *BackgroundColor() const override;
    NSColor *SelectionColor() const override;
    NSColor *CursorColor() const override;
    NSColor *AnsiColor0() const override;
    NSColor *AnsiColor1() const override;
    NSColor *AnsiColor2() const override;
    NSColor *AnsiColor3() const override;
    NSColor *AnsiColor4() const override;
    NSColor *AnsiColor5() const override;
    NSColor *AnsiColor6() const override;
    NSColor *AnsiColor7() const override;
    NSColor *AnsiColor8() const override;
    NSColor *AnsiColor9() const override;
    NSColor *AnsiColorA() const override;
    NSColor *AnsiColorB() const override;
    NSColor *AnsiColorC() const override;
    NSColor *AnsiColorD() const override;
    NSColor *AnsiColorE() const override;
    NSColor *AnsiColorF() const override;
    int MaxFPS() const override;
    enum CursorMode CursorMode() const override;
    bool HideScrollbar() const override;
    
    int StartChangesObserving( std::function<void()> _callback ) override;
    void StopChangesObserving( int _ticket ) override;
};

}
