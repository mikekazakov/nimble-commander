// Copyright (C) 2014-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

#include <Habanero/Observable.h>
#include <Utility/ActionShortcut.h>
#include <unordered_map>
#include <robin_hood.h>
#include <vector>
#include <span>
#include <string_view>

class ActionsShortcutsManager : ObservableBase
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
    ShortCut ShortCutFromAction(const std::string &_action) const;

    /**
     * Return default if can't be found.
     * Overrides has priority over defaults.
     */
    ShortCut ShortCutFromTag(int _tag) const;

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
    struct StringHash {
        using is_transparent = void;
        size_t operator()(std::string_view _str) const noexcept;
    };
    struct StringEqual {
        using is_transparent = void;
        bool operator()(std::string_view _lhs, std::string_view _rhs) const noexcept;
    };

    ActionsShortcutsManager();
    ActionsShortcutsManager(const ActionsShortcutsManager &) = delete;

    void ReadOverrideFromConfig();
    void WriteOverridesToConfig() const;

    robin_hood::unordered_map<int, const char *> m_TagToAction;
    robin_hood::unordered_map<std::string, int, StringHash, StringEqual> m_ActionToTag;
    robin_hood::unordered_map<int, ShortCut> m_ShortCutsDefaults;
    robin_hood::unordered_map<int, ShortCut> m_ShortCutsOverrides;
};

class ActionsShortcutsManager::ShortCutsUpdater
{
public:
    ShortCutsUpdater(std::initializer_list<ShortCut *> _hotkeys,
                     std::initializer_list<const char *> _actions);

private:
    void CheckAndUpdate() const;
    std::vector<std::pair<ShortCut *, int>> m_Pets;
    ObservationTicket m_Ticket;
};

#define IF_MENU_TAG_TOKENPASTE(x, y) x##y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str)                                                                           \
    static const int IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) =                                \
        ActionsShortcutsManager::Instance().TagFromAction(str);                                    \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
