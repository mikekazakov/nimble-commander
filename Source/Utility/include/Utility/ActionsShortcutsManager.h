// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/ActionShortcut.h>
#include <absl/container/inlined_vector.h>
#include <vector>
#include <span>
#include <string_view>
#include <optional>

namespace nc::utility {

class ActionsShortcutsManager
{
public:
    // Shortcut represents a key and its modifiers that have to be pressed to trigger an action.
    using Shortcut = nc::utility::ActionShortcut;

    // An ordered list of shortcuts.
    // The relative order of the shortcuts must be preserved as it has semantic meaning for e.g. menus.
    // Empty shortcuts should not be stored in such vectors.
    // An inlined vector is used to avoid memory allocating for such tiny memory blocks.
    using Shortcuts = absl::InlinedVector<Shortcut, 4>;

    // ActionTags represents a list of numberic action tags.
    // Normally they are tiny, thus an inline vector is used to avoid memory allocation.
    using ActionTags = absl::InlinedVector<int, 4>;

    // Destructor.
    virtual ~ActionsShortcutsManager() = default;

    // Returns a numeric tag that corresponds to the given action name.
    virtual std::optional<int> TagFromAction(std::string_view _action) const noexcept = 0;

    // Returns an action name of the given numeric tag.
    virtual std::optional<std::string_view> ActionFromTag(int _tag) const noexcept = 0;

    // Returns a shortcut assigned to the specified action.
    // Returns std::nullopt such action cannot be found.
    // Overrides have priority over the default shortcuts.
    virtual std::optional<Shortcuts> ShortcutsFromAction(std::string_view _action) const noexcept = 0;

    // Returns a shortcut assigned to the specified numeric action tag.
    // Returns std::nullopt such action cannot be found.
    // Overrides have priority over the default shortcuts.
    virtual std::optional<Shortcuts> ShortcutsFromTag(int _tag) const noexcept = 0;

    // Returns a default shortcut for an action specified by its numeric tag.
    // Returns std::nullopt such action cannot be found.
    virtual std::optional<Shortcuts> DefaultShortcutsFromTag(int _tag) const noexcept = 0;

    // Returns an unordered list of numeric tags of actions that have the specified shortcut.
    // An optional domain parameter can be specified to filter the output by only leaving actions that have the
    // specified domain in their name.
    virtual std::optional<ActionTags> ActionTagsFromShortcut(Shortcut _sc,
                                                             std::string_view _in_domain = {}) const noexcept = 0;

    // Syntax sugar around ActionTagsFromShortCut(_sc, _in_domain) and find_first_of(_of_tags).
    // Returns the first tag from the specified set.
    // The order is not defined in case of ambiguities.
    virtual std::optional<int> FirstOfActionTagsFromShortcut(std::span<const int> _of_tags,
                                                             Shortcut _sc,
                                                             std::string_view _in_domain = {}) const noexcept = 0;
};

} // namespace nc::utility
