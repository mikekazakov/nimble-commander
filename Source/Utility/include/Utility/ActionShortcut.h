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
    struct EventData;

    // Constructs a disabled shortcut
    constexpr ActionShortcut() noexcept = default;

    // Constructs from a persistency utf8 string
    ActionShortcut(std::string_view _from) noexcept;

    // Constructs from an NSEvent/NSEventTypeKeyDown data
    ActionShortcut(const EventData &_event) noexcept;

    // Constructs from data directly
    ActionShortcut(unsigned short _unicode, unsigned long long _modif) noexcept;

    constexpr friend bool operator==(const ActionShortcut &_lhs, const ActionShortcut &_rhs) noexcept = default;

    // Returns true if the shortcut is valid, i.e, has a non-zero unicode character assigned to it.
    operator bool() const noexcept;

#ifdef __OBJC__
    NSString *Key() const noexcept;
    NSString *PrettyString() const noexcept;
#endif
    std::string ToPersString() const noexcept;

    // Lower-case english letters, numbers, generic symbols and control characters.
    // Only characters from Unicode Plane 0 are supported
    unsigned short unicode = 0;

    // Modifiers required for this characters
    NSEventModifierFlagsHolder modifiers = 0;
};

// This structure allows to carry relevant information from NSEvent/NSEventTypeKeyDown in a compact form
struct ActionShortcut::EventData {
    constexpr EventData() noexcept = default;
    EventData(unsigned short _chmod, unsigned short _chunmod, unsigned short _kc, unsigned long _mods) noexcept;
#ifdef __OBJC__
    EventData(NSEvent *_event) noexcept;
#endif
    unsigned short char_with_modifiers = 0;
    unsigned short char_without_modifiers = 0;
    unsigned short key_code = 0;
    unsigned long modifiers = 0;
};

} // namespace nc::utility

template <>
struct std::hash<nc::utility::ActionShortcut> {
    size_t operator()(const nc::utility::ActionShortcut &) const noexcept;
};

#ifdef __OBJC__
@interface NSMenuItem (ActionShortcutSupport)

- (void)nc_setKeyEquivalentWithShortcut:(nc::utility::ActionShortcut)_shortcut;

@end
#endif
