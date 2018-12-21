// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>

namespace nc::panel {

class FooterTheme
{
public:
    virtual ~FooterTheme() = default;
    virtual NSFont  *Font() const = 0;
    virtual NSColor *TextColor() const = 0;
    virtual NSColor *ActiveTextColor() const = 0;
    virtual NSColor *SeparatorsColor() const = 0;
    virtual NSColor *ActiveBackgroundColor() const = 0;
    virtual NSColor *InactiveBackgroundColor() const = 0;
    virtual void ObserveChanges( std::function<void()> _callback ) = 0;
};
    
}
