// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>

namespace nc::viewer {
    
class Theme
{
public:
    virtual ~Theme() = default;
    virtual NSFont  *Font() const = 0;
    virtual NSColor *OverlayColor() const = 0;
    virtual NSColor *TextColor() const = 0;
    virtual NSColor *ViewerSelectionColor() const = 0;
    virtual NSColor *ViewerBackgroundColor() const = 0;
    virtual void ObserveChanges( std::function<void()> _callback ) = 0;
};
    
}
