//
//  ActionsShortcutsManager.h
//  Files
//
//  Created by Michael G. Kazakov on 26.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

// ⇧ - NSShiftKeyMask
// % - fn <- NO
// ^ - NSControlKeyMask
// ⌥ - NSAlternateKeyMask
// ⌘ - NSCommandKeyMask

#include "ActionShortcut.h"

class ActionsShortcutsManager
{
public:
    using ShortCut = ::ActionShortcut;
    class ShortCutsUpdater;
    
    static ActionsShortcutsManager &Instance();
    
    /**
     * Return -1 on if tag corresponing _action wasn't found.
     */
    int TagFromAction(const string &_action) const;
    
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
    
    const vector<pair<string,int>>& AllShortcuts() const;
    
    nanoseconds LastChanged() const;
    
private:
    ActionsShortcutsManager();
    ActionsShortcutsManager(const ActionsShortcutsManager&) = delete;
    
    void ReadOverrides(NSArray *_dict);
    void WriteOverrides(NSMutableArray *_dict) const;
    bool WriteOverridesToConfigFile() const;
    
    unordered_map<int, string>        m_TagToAction;
    unordered_map<string, int>        m_ActionToTag;
    unordered_map<int, ShortCut>      m_ShortCutsDefaults;
    unordered_map<int, ShortCut>      m_ShortCutsOverrides;
    nanoseconds                       m_LastChanged;
};



class ActionsShortcutsManager::ShortCutsUpdater
{
public:
    ShortCutsUpdater( initializer_list<ShortCut*> _hotkeys, initializer_list<const char*> _actions );
    
    void CheckAndUpdate();
private:
    vector< pair<ShortCut*, int> >  m_Pets;
    nanoseconds                     m_LastUpdated;
};

#define IF_MENU_TAG_TOKENPASTE(x, y) x ## y
#define IF_MENU_TAG_TOKENPASTE2(x, y) IF_MENU_TAG_TOKENPASTE(x, y)
#define IF_MENU_TAG(str) static const long IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) = ActionsShortcutsManager::Instance().TagFromAction(str); \
    if( tag == IF_MENU_TAG_TOKENPASTE2(__tag_no_, __LINE__) )
