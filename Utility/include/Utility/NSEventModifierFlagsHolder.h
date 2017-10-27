// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <AppKit/NSEvent.h>

struct NSEventModifierFlagsHolder
{
    uint8_t flags;
    
    inline NSEventModifierFlagsHolder() noexcept : flags(0)
        { static_assert( NSEventModifierFlagCapsLock == 1 << 16 );
          static_assert( sizeof(NSEventModifierFlagsHolder) == 1 ); }
    inline NSEventModifierFlagsHolder( NSEventModifierFlags _flags ) noexcept :
        flags( ((_flags & NSEventModifierFlagDeviceIndependentFlagsMask) >> 16) & 0xFF ) {}
    
    inline bool is_empty()      const noexcept
        { return flags == 0; }
    inline bool is_capslock()   const noexcept
        { return flags & (NSEventModifierFlagCapsLock     >> 16); }
    inline bool is_shift()      const noexcept
        { return flags & (NSEventModifierFlagShift        >> 16); }
    inline bool is_control()    const noexcept
        { return flags & (NSEventModifierFlagControl      >> 16); }
    inline bool is_option()     const noexcept
        { return flags & (NSEventModifierFlagOption       >> 16); }
    inline bool is_command()    const noexcept
        { return flags & (NSEventModifierFlagCommand      >> 16); }
    inline bool is_numpad()     const noexcept
        { return flags & (NSEventModifierFlagNumericPad   >> 16); }
    inline bool is_help()       const noexcept
        { return flags & (NSEventModifierFlagHelp         >> 16); }
    inline bool is_func()       const noexcept
        { return flags & (NSEventModifierFlagFunction     >> 16); }
    
    inline bool operator==(const NSEventModifierFlagsHolder&_rhs) const noexcept
        { return flags == _rhs.flags; }
    inline bool operator!=(const NSEventModifierFlagsHolder&_rhs) const noexcept
        { return flags != _rhs.flags; }
    inline operator NSEventModifierFlags() const noexcept
        { return ((uint64_t)flags) << 16; }
};
