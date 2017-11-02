// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

#include <Habanero/Observable.h>
#include "ActionShortcut.h"

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
    int TagFromAction(const string &_action) const;
    int TagFromAction(const char *_action) const;
    
    /**
     * return "" on if action corresponing _tag wasn't found.
     */
    string ActionFromTag(int _tag) const;
    
    /**
     * Return default if can't be found.
     * Overrides has priority over defaults.
     */
    ShortCut ShortCutFromAction(const string &_action) const;

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
    
    bool SetShortCutOverride(const string &_action, const ShortCut& _sc);
    
    void SetMenuShortCuts(NSMenu *_menu) const;
    
    const vector<pair<const char*,int>>& AllShortcuts() const;
    
    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(function<void()> _callback);
    
private:
    ActionsShortcutsManager();
    ActionsShortcutsManager(const ActionsShortcutsManager&) = delete;
    
    void ReadOverrideFromConfig();
    void WriteOverridesToConfig() const;
    
    unordered_map<int, const char*> m_TagToAction;
    unordered_map<string, int>      m_ActionToTag;
    unordered_map<int, ShortCut>    m_ShortCutsDefaults;
    unordered_map<int, ShortCut>    m_ShortCutsOverrides;
};

class ActionsShortcutsManager::ShortCutsUpdater
{
public:
    ShortCutsUpdater( initializer_list<ShortCut*> _hotkeys, initializer_list<const char*> _actions );
private:
    void CheckAndUpdate() const;
    vector< pair<ShortCut*, int> >  m_Pets;
    ObservationTicket               m_Ticket;
};

#define IF_MENU_TAG_TOKENPASTE(x, y) x ## y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str) static const int IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) = ActionsShortcutsManager::Instance().TagFromAction(str); \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
