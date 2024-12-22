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
#include <vector>
#include <span>
#include <string_view>
#include <Cocoa/Cocoa.h>

namespace nc::config {
class Config;
}

namespace nc::core {

class ActionsShortcutsManager : nc::base::ObservableBase
{
public:
    using ShortCut = nc::utility::ActionShortcut;
    struct AutoUpdatingShortCut;
    class ShortCutsUpdater;

    // Create a new shortcut manager which will use the provided config to store the overides.
    ActionsShortcutsManager(nc::config::Config &_config);

    // A shared instance of a manager, it uses the GlobalConfig() as its data backend.
    static ActionsShortcutsManager &Instance();

    /**
     * Returns -1 on if tag corresponing _action wasn't found.
     */
    static int TagFromAction(std::string_view _action) noexcept;

    /**
     * return "" on if action corresponing _tag wasn't found.
     */
    static std::string_view ActionFromTag(int _tag) noexcept;

    /**
     * Returns default if can't be found.
     * Overrides has priority over defaults.
     */
    ShortCut ShortCutFromAction(std::string_view _action) const noexcept;

    /**
     * Returns default if can't be found.
     * Overrides has priority over defaults.
     */
    ShortCut ShortCutFromTag(int _tag) const noexcept;

    /**
     * Returns default if can't be found.
     */
    ShortCut DefaultShortCutFromTag(int _tag) const;

    void RevertToDefaults();

    bool SetShortCutOverride(std::string_view _action, const ShortCut &_sc);

    void SetMenuShortCuts(NSMenu *_menu) const;

    static std::span<const std::pair<const char *, int>> AllShortcuts();

    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(std::function<void()> _callback);

private:
    ActionsShortcutsManager(const ActionsShortcutsManager &) = delete;

    void ReadOverrideFromConfig();
    void WriteOverridesToConfig() const;

    ankerl::unordered_dense::map<int, ShortCut> m_ShortCutsDefaults;
    ankerl::unordered_dense::map<int, ShortCut> m_ShortCutsOverrides;
    nc::config::Config &m_Config;
};

class ActionsShortcutsManager::ShortCutsUpdater
{
public:
    struct UpdateTarget {
        ShortCut *shortcut;
        const char *action;
    };

    ShortCutsUpdater(std::span<const UpdateTarget> _targets);

private:
    void CheckAndUpdate() const;
    std::vector<std::pair<ShortCut *, int>> m_Targets;
    ObservationTicket m_Ticket;
};

} // namespace nc::core

#define IF_MENU_TAG_TOKENPASTE(x, y) x##y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str)                                                                                               \
    static const int IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) =                                                    \
        nc::core::ActionsShortcutsManager::Instance().TagFromAction(str);                                              \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
