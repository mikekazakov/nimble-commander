// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <AppKit/NSEvent.h>
#include <cstdint>

namespace nc::utility {

struct NSEventModifierFlagsHolder
{
    std::uint8_t flags;
    
    inline NSEventModifierFlagsHolder() noexcept : flags(0)
        { static_assert( NSEventModifierFlagCapsLock == 1 << offset );
          static_assert( sizeof(NSEventModifierFlagsHolder) == 1 ); }
    inline NSEventModifierFlagsHolder( NSEventModifierFlags _flags ) noexcept :
        flags( ((_flags & NSEventModifierFlagDeviceIndependentFlagsMask) >> offset) & 0xFF ) {}
    
    inline bool is_empty()      const noexcept
        { return flags == 0; }
    inline bool is_capslock()   const noexcept
        { return flags & (NSEventModifierFlagCapsLock     >> offset); }
    inline bool is_shift()      const noexcept
        { return flags & (NSEventModifierFlagShift        >> offset); }
    inline bool is_control()    const noexcept
        { return flags & (NSEventModifierFlagControl      >> offset); }
    inline bool is_option()     const noexcept
        { return flags & (NSEventModifierFlagOption       >> offset); }
    inline bool is_command()    const noexcept
        { return flags & (NSEventModifierFlagCommand      >> offset); }
    inline bool is_numpad()     const noexcept
        { return flags & (NSEventModifierFlagNumericPad   >> offset); }
    inline bool is_help()       const noexcept
        { return flags & (NSEventModifierFlagHelp         >> offset); }
    inline bool is_func()       const noexcept
        { return flags & (NSEventModifierFlagFunction     >> offset); }
    
    inline bool operator==(const NSEventModifierFlagsHolder&_rhs) const noexcept
        { return flags == _rhs.flags; }
    inline bool operator!=(const NSEventModifierFlagsHolder&_rhs) const noexcept
        { return flags != _rhs.flags; }
    inline operator NSEventModifierFlags() const noexcept
        { return static_cast<std::uint64_t>(flags) << offset; }
    
private:
    static constexpr int offset = 16;
};

}
