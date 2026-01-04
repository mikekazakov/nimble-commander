// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>

namespace nc::viewer {

class Theme
{
public:
    virtual ~Theme() = default;
    [[nodiscard]] virtual NSFont *Font() const = 0;
    [[nodiscard]] virtual NSColor *OverlayColor() const = 0;
    [[nodiscard]] virtual NSColor *TextColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxCommentColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxPreprocessorColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxKeywordColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxOperatorColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxIdentifierColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxNumberColor() const = 0;
    [[nodiscard]] virtual NSColor *TextSyntaxStringColor() const = 0;
    [[nodiscard]] virtual NSColor *ViewerSelectionColor() const = 0;
    [[nodiscard]] virtual NSColor *ViewerBackgroundColor() const = 0;
    virtual void ObserveChanges(std::function<void()> _callback) = 0;
};

} // namespace nc::viewer
