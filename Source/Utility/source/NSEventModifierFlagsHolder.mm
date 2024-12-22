// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.

#include <Utility/NSEventModifierFlagsHolder.h>
#include <AppKit/AppKit.h>

namespace nc::utility {

void NSEventModifierFlagsHolder::check_flag_values()
{
    static_assert(NSEventModifierFlagCapsLock == 1 << offset);
    static_assert(sizeof(NSEventModifierFlagsHolder) == 1);
    static_assert(flag_caps_lock == NSEventModifierFlagCapsLock);
    static_assert(flag_shift == NSEventModifierFlagShift);
    static_assert(flag_control == NSEventModifierFlagControl);
    static_assert(flag_option == NSEventModifierFlagOption);
    static_assert(flag_command == NSEventModifierFlagCommand);
    static_assert(flag_numeric_pad == NSEventModifierFlagNumericPad);
    static_assert(flag_help == NSEventModifierFlagHelp);
    static_assert(flag_function == NSEventModifierFlagFunction);
    static_assert(flag_mask == NSEventModifierFlagDeviceIndependentFlagsMask);
}

} // namespace nc::utility
