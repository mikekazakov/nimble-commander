// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "CursorMode.h"
#include <functional>

#ifdef __OBJC__
@class NSFont;
@class NSColor;
#else
using NSFont = void *;
using NSColor = void *;
#endif

namespace nc::term {

class Settings
{
public:
    virtual ~Settings() = 0;
    [[nodiscard]] virtual NSFont *Font() const = 0;
    [[nodiscard]] virtual NSColor *ForegroundColor() const = 0;
    [[nodiscard]] virtual NSColor *BoldForegroundColor() const = 0;
    [[nodiscard]] virtual NSColor *BackgroundColor() const = 0;
    [[nodiscard]] virtual NSColor *SelectionColor() const = 0;
    [[nodiscard]] virtual NSColor *CursorColor() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor0() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor1() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor2() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor3() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor4() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor5() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor6() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor7() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor8() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColor9() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColorA() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColorB() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColorC() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColorD() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColorE() const = 0;
    [[nodiscard]] virtual NSColor *AnsiColorF() const = 0;
    [[nodiscard]] virtual int MaxFPS() const = 0;
    [[nodiscard]] virtual enum CursorMode CursorMode() const = 0;
    [[nodiscard]] virtual bool HideScrollbar() const = 0;

    virtual int StartChangesObserving(std::function<void()> _callback) = 0;
    virtual void StopChangesObserving(int _ticket) = 0;
};

class DefaultSettings : public Settings
{
public:
    static std::shared_ptr<Settings> SharedDefaultSettings();
    [[nodiscard]] NSFont *Font() const override;
    [[nodiscard]] NSColor *ForegroundColor() const override;
    [[nodiscard]] NSColor *BoldForegroundColor() const override;
    [[nodiscard]] NSColor *BackgroundColor() const override;
    [[nodiscard]] NSColor *SelectionColor() const override;
    [[nodiscard]] NSColor *CursorColor() const override;
    [[nodiscard]] NSColor *AnsiColor0() const override;
    [[nodiscard]] NSColor *AnsiColor1() const override;
    [[nodiscard]] NSColor *AnsiColor2() const override;
    [[nodiscard]] NSColor *AnsiColor3() const override;
    [[nodiscard]] NSColor *AnsiColor4() const override;
    [[nodiscard]] NSColor *AnsiColor5() const override;
    [[nodiscard]] NSColor *AnsiColor6() const override;
    [[nodiscard]] NSColor *AnsiColor7() const override;
    [[nodiscard]] NSColor *AnsiColor8() const override;
    [[nodiscard]] NSColor *AnsiColor9() const override;
    [[nodiscard]] NSColor *AnsiColorA() const override;
    [[nodiscard]] NSColor *AnsiColorB() const override;
    [[nodiscard]] NSColor *AnsiColorC() const override;
    [[nodiscard]] NSColor *AnsiColorD() const override;
    [[nodiscard]] NSColor *AnsiColorE() const override;
    [[nodiscard]] NSColor *AnsiColorF() const override;
    [[nodiscard]] int MaxFPS() const override;
    [[nodiscard]] enum CursorMode CursorMode() const override;
    [[nodiscard]] bool HideScrollbar() const override;

    int StartChangesObserving(std::function<void()> _callback) override;
    void StopChangesObserving(int _ticket) override;
};

} // namespace nc::term
