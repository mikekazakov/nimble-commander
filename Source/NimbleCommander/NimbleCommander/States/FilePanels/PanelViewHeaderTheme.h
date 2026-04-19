// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>

namespace nc::panel {

class HeaderTheme
{
public:
    virtual ~HeaderTheme() = default;
    [[nodiscard]] virtual NSFont *Font() const = 0;
    [[nodiscard]] virtual NSColor *TextColor() const = 0;
    [[nodiscard]] virtual NSColor *ActiveTextColor() const = 0;
    [[nodiscard]] virtual NSColor *ActiveBackgroundColor() const = 0;
    [[nodiscard]] virtual NSColor *InactiveBackgroundColor() const = 0;
    [[nodiscard]] virtual NSColor *SeparatorColor() const = 0;
    [[nodiscard]] virtual NSColor *PathSeparatorColor() const = 0;
    [[nodiscard]] virtual NSColor *PathAccentColor() const = 0;
    [[nodiscard]] virtual unsigned PathHoverPadX() const = 0;
    [[nodiscard]] virtual unsigned PathHoverPadYTop() const = 0;
    [[nodiscard]] virtual unsigned PathHoverPadYBottom() const = 0;
    [[nodiscard]] virtual unsigned PathHoverCornerRadius() const = 0;
    virtual void ObserveChanges(std::function<void()> _callback) = 0;
};

} // namespace nc::panel
