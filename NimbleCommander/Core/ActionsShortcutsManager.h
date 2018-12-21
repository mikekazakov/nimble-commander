// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

#include <Habanero/Observable.h>
#include "ActionShortcut.h"
#include <unordered_map>
#include <vector>
#include <Cocoa/Cocoa.h>

class ActionsShortcutsManager : ObservableBase
{
public:
    using ShortCut = ::ActionShortcut;
    struct AutoUpdatingShortCut;
    class ShortCutsUpdater;
    
    static ActionsShortcutsManager &Instance();
    
    /**
     * Return -1 on if tag corresponing _action wasn't found.
     */
    int TagFromAction(const std::string &_action) const;
    int TagFromAction(const char *_action) const;
    
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
    
    bool SetShortCutOverride(const std::string &_action, const ShortCut& _sc);
    
    void SetMenuShortCuts(NSMenu *_menu) const;
    
    const std::vector<std::pair<const char*,int>>& AllShortcuts() const;
    
    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(std::function<void()> _callback);
    
private:
    ActionsShortcutsManager();
    ActionsShortcutsManager(const ActionsShortcutsManager&) = delete;
    
    void ReadOverrideFromConfig();
    void WriteOverridesToConfig() const;
    
    std::unordered_map<int, const char*> m_TagToAction;
    std::unordered_map<std::string, int>      m_ActionToTag;
    std::unordered_map<int, ShortCut>    m_ShortCutsDefaults;
    std::unordered_map<int, ShortCut>    m_ShortCutsOverrides;
};

class ActionsShortcutsManager::ShortCutsUpdater
{
public:
    ShortCutsUpdater(std::initializer_list<ShortCut*> _hotkeys,
                     std::initializer_list<const char*> _actions );
private:
    void CheckAndUpdate() const;
    std::vector< std::pair<ShortCut*, int> >  m_Pets;
    ObservationTicket               m_Ticket;
};

#define IF_MENU_TAG_TOKENPASTE(x, y) x ## y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str) static const int IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) = ActionsShortcutsManager::Instance().TagFromAction(str); \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
