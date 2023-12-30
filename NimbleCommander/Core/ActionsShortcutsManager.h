// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

#include <Habanero/Observable.h>
#include <Habanero/RobinHoodUtil.h>
#include <Utility/ActionShortcut.h>
#include <robin_hood.h>
#include <vector>
#include <span>
#include <string_view>
#include <Cocoa/Cocoa.h>

class ActionsShortcutsManager : nc::base::ObservableBase
{
public:
    using ShortCut = nc::utility::ActionShortcut;
    struct AutoUpdatingShortCut;
    class ShortCutsUpdater;

    static ActionsShortcutsManager &Instance();

    /**
     * Return -1 on if tag corresponing _action wasn't found.
     */
    int TagFromAction(std::string_view _action) const noexcept;

    /**
     * return "" on if action corresponing _tag wasn't found.
     */
    std::string ActionFromTag(int _tag) const;

    /**
     * Return default if can't be found.
     * Overrides has priority over defaults.
     */
    ShortCut ShortCutFromAction(std::string_view _action) const noexcept;

    /**
     * Return default if can't be found.
     * Overrides has priority over defaults.
     */
    ShortCut ShortCutFromTag(int _tag) const noexcept;

    /**
     * Return default if can't be found.
     */
    ShortCut DefaultShortCutFromTag(int _tag) const;

    void RevertToDefaults();

    bool SetShortCutOverride(const std::string &_action, const ShortCut &_sc);

    void SetMenuShortCuts(NSMenu *_menu) const;

    std::span<const std::pair<const char *, int>> AllShortcuts() const;

    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(std::function<void()> _callback);

private:
    ActionsShortcutsManager();
    ActionsShortcutsManager(const ActionsShortcutsManager &) = delete;

    void ReadOverrideFromConfig();
    void WriteOverridesToConfig() const;

    robin_hood::unordered_flat_map<int, const char *> m_TagToAction;
    robin_hood::unordered_flat_map<std::string,
                                   int,
                                   nc::RHTransparentStringHashEqual,
                                   nc::RHTransparentStringHashEqual>
        m_ActionToTag;
    robin_hood::unordered_flat_map<int, ShortCut> m_ShortCutsDefaults;
    robin_hood::unordered_flat_map<int, ShortCut> m_ShortCutsOverrides;
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

#define IF_MENU_TAG_TOKENPASTE(x, y) x##y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str)                                                                           \
    static const int IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) =                                \
        ActionsShortcutsManager::Instance().TagFromAction(str);                                    \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
