// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/NSEventModifierFlagsHolder.h>
#include <string>
#include <string_view>
#include <functional>
#include <compare>
#include <stdint.h>

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#endif

namespace nc::utility {

struct ActionShortcut {
    // Constructs a disabled shortcut
    constexpr ActionShortcut() noexcept = default;

    // Constructs from a persistency utf8 string
    ActionShortcut(std::string_view _from) noexcept;

    // Constructs from a persistency utf8 string, wrapper for C++20-style u8 characters
    ActionShortcut(std::u8string_view _from) noexcept;

    // Construct from data directly
    ActionShortcut(unsigned short _unicode, unsigned long long _modif) noexcept;

    friend bool operator==(const ActionShortcut &_lhs, const ActionShortcut &_rhs) noexcept = default;
    friend bool operator!=(const ActionShortcut &_lhs, const ActionShortcut &_rhs) noexcept = default;
    operator bool() const noexcept;

#ifdef __OBJC__
    NSString *Key() const noexcept;
    NSString *PrettyString() const noexcept;
#endif
    std::string ToPersString() const noexcept;

    struct EventData {
        EventData() noexcept;
        EventData(unsigned short _chmod, unsigned short _chunmod, unsigned short _kc, unsigned long _mods) noexcept;
#ifdef __OBJC__
        EventData(NSEvent *_event) noexcept;
#endif
        unsigned short char_with_modifiers;
        unsigned short char_without_modifiers;
        unsigned short key_code;
        unsigned long modifiers;
    };

    bool IsKeyDown(EventData _event) const noexcept;

    // Lower-case english letters, numbers, generic symbols and control characters.
    // Only characters from Unicode Plane 0 are supported
    unsigned short unicode = 0;

    // Modifiers required for this characters
    NSEventModifierFlagsHolder modifiers = 0;
};

} // namespace nc::utility

template <>
struct std::hash<nc::utility::ActionShortcut> {
    size_t operator()(const nc::utility::ActionShortcut &) const noexcept;
};

#ifdef __OBJC__
@interface NSMenuItem (NCAdditions)

- (void)nc_setKeyEquivalentWithShortcut:(nc::utility::ActionShortcut)_shortcut;

@end
#endif
