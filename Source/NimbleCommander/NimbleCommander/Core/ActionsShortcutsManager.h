// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

#include <Base/Observable.h>
#include <Base/UnorderedUtil.h>
#include <Utility/ActionShortcut.h>
#include <Utility/ActionsShortcutsManager.h>
#include <absl/container/inlined_vector.h>
#include <vector>
#include <span>
#include <string_view>
#include <optional>

namespace nc::config {
class Config;
}

namespace nc::core {

class ActionsShortcutsManager : public nc::utility::ActionsShortcutsManager, private nc::base::ObservableBase
{
public:
    // Create a new shortcut manager which will use the provided config to store the overides.
    ActionsShortcutsManager(nc::config::Config &_config);

    // Destructor.
    virtual ~ActionsShortcutsManager();

    // A shared instance of a manager, it uses the GlobalConfig() as its data backend.
    static ActionsShortcutsManager &Instance();

    // Returns a numeric tag that corresponds to the given action name.
    std::optional<int> TagFromAction(std::string_view _action) const noexcept override;

    // Returns an action name of the given numeric tag.
    std::optional<std::string_view> ActionFromTag(int _tag) const noexcept override;

    // Returns a shortcut assigned to the specified action.
    // Returns std::nullopt such action cannot be found.
    // Overrides have priority over the default shortcuts.
    std::optional<Shortcuts> ShortcutsFromAction(std::string_view _action) const noexcept override;

    // Returns a shortcut assigned to the specified numeric action tag.
    // Returns std::nullopt such action cannot be found.
    // Overrides have priority over the default shortcuts.
    std::optional<Shortcuts> ShortcutsFromTag(int _tag) const noexcept override;

    // Returns a default shortcut for an action specified by its numeric tag.
    // Returns std::nullopt such action cannot be found.
    std::optional<Shortcuts> DefaultShortcutsFromTag(int _tag) const noexcept override;

    // Returns an unordered list of numeric tags of actions that have the specified shortcut.
    // An optional domain parameter can be specified to filter the output by only leaving actions that have the
    // specified domain in their name.
    std::optional<ActionTags> ActionTagsFromShortcut(Shortcut _sc,
                                                     std::string_view _in_domain = {}) const noexcept override;

    // Syntax sugar around ActionTagsFromShortCut(_sc, _in_domain) and find_first_of(_of_tags).
    // Returns the first tag from the specified set.
    // The order is not defined in case of ambiguities.
    std::optional<int> FirstOfActionTagsFromShortcut(std::span<const int> _of_tags,
                                                     Shortcut _sc,
                                                     std::string_view _in_domain = {}) const noexcept override;

    // Removes any hotkeys overrides.
    void RevertToDefaults();

    // Sets the custom shortkey for the specified action.
    // Returns true if any change was done to the actions maps.
    // If the _action doesn't exist or already has the same value, returns false.
    // This function is effectively a syntax sugar for SetShortCutsOverride(_action, {&_sc, 1}).
    bool SetShortcutOverride(std::string_view _action, Shortcut _sc);

    // Sets the custom shortkeys for the specified action.
    // Returns true if any change was done to the actions maps.
    // If the _action doesn't exist or already has the same value, returns false.
    bool SetShortcutsOverride(std::string_view _action, std::span<const Shortcut> _shortcuts);

    static std::span<const std::pair<const char *, int>> AllShortcuts();

    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(std::function<void()> _callback);

private:
    // An unordered list of numeric tags indicating which actions are using a shortcut.
    // An inlined vector is used to avoid memory allocating for such tiny memory blocks.
    using TagsUsingShortcut = absl::InlinedVector<int, 4>;

    ActionsShortcutsManager(const ActionsShortcutsManager &) = delete;

    void ReadOverrideFromConfig();
    void WriteOverridesToConfig() const;

    // Clears the shortcuts usage map and builds it from the defaults and the overrides
    void BuildShortcutUsageMap() noexcept;

    // Adds the specified action tag to a list of actions that use the specified shortcut.
    // The shortcut should not be empty.
    void RegisterShortcutUsage(Shortcut _shortcut, int _tag) noexcept;

    // Removes the specified actions tag from the list of action tags that use the specified shortcut.
    void UnregisterShortcutUsage(Shortcut _shortcut, int _tag) noexcept;

    // Returns a container without empty shortcuts, while preserving the original relative order of the remaining items.
    // Duplicates are removed as well.
    static Shortcuts SanitizedShortcuts(const Shortcuts &_shortcuts) noexcept;

    // Maps an action tag to the default ordered list of its shortcuts.
    ankerl::unordered_dense::map<int, Shortcuts> m_ShortcutsDefaults;

    // Maps an action tag to the overriden ordered list of its shortcuts.
    ankerl::unordered_dense::map<int, Shortcuts> m_ShortcutsOverrides;

    // Maps a shortcut to an unordered list of action tags that use it.
    ankerl::unordered_dense::map<Shortcut, TagsUsingShortcut> m_ShortcutsUsage;

    // Config instance used to read from and write to the shortcut overrides.
    nc::config::Config &m_Config;
};

} // namespace nc::core

#ifdef __OBJC__

@interface NSMenu (ActionsShortcutsManagerSupport)

- (void)nc_setMenuItemShortcutsWithActionsShortcutsManager:(const nc::core::ActionsShortcutsManager &)_asm;

@end

#endif
