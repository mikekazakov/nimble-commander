// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <cstdint>

#ifdef __OBJC__
#include <AppKit/AppKit.h>
#endif

namespace nc::utility {

struct NSEventModifierFlagsHolder {
    std::uint8_t flags = 0;

    constexpr NSEventModifierFlagsHolder() noexcept = default;

#ifdef __OBJC__
    constexpr NSEventModifierFlagsHolder(NSEventModifierFlags _flags) noexcept
#else
    constexpr NSEventModifierFlagsHolder(unsigned long _flags) noexcept
#endif
        : flags(((_flags & flag_mask) >> offset) & 0xFF)
    {
    }

    constexpr bool is_empty() const noexcept { return flags == 0; }

    constexpr bool is_capslock() const noexcept { return flags & (flag_caps_lock >> offset); }

    constexpr bool is_shift() const noexcept { return flags & (flag_shift >> offset); }

    constexpr bool is_control() const noexcept { return flags & (flag_control >> offset); }

    constexpr bool is_option() const noexcept { return flags & (flag_option >> offset); }

    constexpr bool is_command() const noexcept { return flags & (flag_command >> offset); }

    constexpr bool is_numpad() const noexcept { return flags & (flag_numeric_pad >> offset); }

    constexpr bool is_help() const noexcept { return flags & (flag_help >> offset); }

    constexpr bool is_func() const noexcept { return flags & (flag_function >> offset); }

    constexpr bool operator==(const NSEventModifierFlagsHolder &_rhs) const noexcept = default;

#ifdef __OBJC__
    constexpr operator NSEventModifierFlags() const noexcept { return static_cast<std::uint64_t>(flags) << offset; }
#endif

private:
    static void check_flag_values();

    static constexpr int offset = 16;
    static constexpr unsigned long flag_caps_lock = 1ul << 16;
    static constexpr unsigned long flag_shift = 1ul << 17;
    static constexpr unsigned long flag_control = 1ul << 18;
    static constexpr unsigned long flag_option = 1ul << 19;
    static constexpr unsigned long flag_command = 1ul << 20;
    static constexpr unsigned long flag_numeric_pad = 1ul << 21;
    static constexpr unsigned long flag_help = 1ul << 22;
    static constexpr unsigned long flag_function = 1ul << 23;
    static constexpr unsigned long flag_mask = 0xffff0000ul;
};

} // namespace nc::utility
