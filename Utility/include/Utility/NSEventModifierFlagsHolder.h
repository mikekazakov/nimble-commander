// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <AppKit/NSEvent.h>
#include <cstdint>

namespace nc::utility {

struct NSEventModifierFlagsHolder
{
    std::uint8_t flags;
    
    NSEventModifierFlagsHolder() noexcept : flags(0)
        { static_assert( NSEventModifierFlagCapsLock == 1 << offset );
          static_assert( sizeof(NSEventModifierFlagsHolder) == 1 ); }
    NSEventModifierFlagsHolder( NSEventModifierFlags _flags ) noexcept :
        flags( ((_flags & NSEventModifierFlagDeviceIndependentFlagsMask) >> offset) & 0xFF ) {}
    
    bool is_empty()      const noexcept
        { return flags == 0; }
    bool is_capslock()   const noexcept
        { return flags & (NSEventModifierFlagCapsLock     >> offset); }
    bool is_shift()      const noexcept
        { return flags & (NSEventModifierFlagShift        >> offset); }
    bool is_control()    const noexcept
        { return flags & (NSEventModifierFlagControl      >> offset); }
    bool is_option()     const noexcept
        { return flags & (NSEventModifierFlagOption       >> offset); }
    bool is_command()    const noexcept
        { return flags & (NSEventModifierFlagCommand      >> offset); }
    bool is_numpad()     const noexcept
        { return flags & (NSEventModifierFlagNumericPad   >> offset); }
    bool is_help()       const noexcept
        { return flags & (NSEventModifierFlagHelp         >> offset); }
    bool is_func()       const noexcept
        { return flags & (NSEventModifierFlagFunction     >> offset); }
    
    bool operator==(const NSEventModifierFlagsHolder&_rhs) const noexcept
        { return flags == _rhs.flags; }
    bool operator!=(const NSEventModifierFlagsHolder&_rhs) const noexcept
        { return flags != _rhs.flags; }
    operator NSEventModifierFlags() const noexcept
        { return static_cast<std::uint64_t>(flags) << offset; }
    
private:
    static constexpr int offset = 16;
};

}
