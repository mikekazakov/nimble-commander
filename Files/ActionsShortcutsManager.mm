//
//  ActionsShortcutsManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "ActionsShortcutsManager.h"

static NSString *g_OverridesDefaultsKey = @"CommonHotkeysOverrides";

static NSString *OverridesFullPathOld()
{
    static NSString *g_OverridesFilenameOld = @"/shortcuts.plist";
    return [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingString:g_OverridesFilenameOld];
}

NSString *ActionsShortcutsManager::ShortCut::ToPersString() const
{
    NSString *result = [NSString new];
    if(modifiers & NSShiftKeyMask)
        result = [result stringByAppendingString:@"⇧"];
    if(modifiers & NSControlKeyMask)
        result = [result stringByAppendingString:@"^"];
    if(modifiers & NSAlternateKeyMask)
        result = [result stringByAppendingString:@"⌥"];
    if(modifiers & NSCommandKeyMask)
        result = [result stringByAppendingString:@"⌘"];

    if(key != nil)
    {
        NSString *str = key;
        if([str isEqualToString:@"\r"])
            str = @"\\r";
    
        result = [result stringByAppendingString:str];
    }
    
    return result;
}

bool ActionsShortcutsManager::ShortCut::FromStringAndModif(NSString *_from, unsigned long _modif)
{
    if(_from == nil || _from.length == 0)
        return false;
    key = _from;
    unic = [_from characterAtIndex:0];
    modifiers = 0;
    if(_modif & NSShiftKeyMask)     modifiers |= NSShiftKeyMask;
    if(_modif & NSControlKeyMask)   modifiers |= NSControlKeyMask;
    if(_modif & NSAlternateKeyMask) modifiers |= NSAlternateKeyMask;
    if(_modif & NSCommandKeyMask)   modifiers |= NSCommandKeyMask;
    return true;
}

bool ActionsShortcutsManager::ShortCut::FromPersString(NSString *_from)
{
    if(_from.length == 0)
    {
        modifiers = 0;
        key = @"";
        unic = 0;
        return true;
    }
    
    int len = (int)_from.length;
    unsigned mod_ = 0;
    NSString *key_ = nil;
    for(int i = 0; i < len; ++i)
    {
        unichar c = [_from characterAtIndex:i];
        if(c == u'⇧') {
            mod_ |= NSShiftKeyMask;
            continue;
        }
        if(c == u'^') {
            mod_ |= NSControlKeyMask;
            continue;
        }
        if(c == u'⌥') {
            mod_ |= NSAlternateKeyMask;
            continue;
        }
        if(c == u'⌘') {
            mod_ |= NSCommandKeyMask;
            continue;
        }
      
        key_ = [_from substringFromIndex:i];
        break;
    }
    
    if(key_ == nil)
        return false;
    
    if([key_ isEqualToString:@"\\r"])
        key_ = @"\r";
    else if([key_ isEqualToString:@"\\t"])
        key_ = @"\t";
    
    
    modifiers = mod_;
    key = key_;
    unic = [key characterAtIndex:0];
    
    return true;
}

bool ActionsShortcutsManager::ShortCut::IsKeyDown(unichar _unicode, unsigned short _keycode, unsigned long _modifiers) const
{
    // exclude CapsLock from our decision process
    unsigned long clean_modif = _modifiers &
        (NSDeviceIndependentModifierFlagsMask & ~NSAlphaShiftKeyMask);
    
    return modifiers == clean_modif &&
                unic == _unicode;
}

bool ActionsShortcutsManager::ShortCut::operator==(const ShortCut&_r) const
{
    if(modifiers != _r.modifiers)
        return false;
    if(unic != _r.unic)
        return false;
    if(![key isEqualToString:_r.key])
        return false;
    return true;
}

bool ActionsShortcutsManager::ShortCut::operator!=(const ShortCut&_r) const
{
    return !(*this == _r);
}

ActionsShortcutsManager::ActionsShortcutsManager()
{
    for(auto &i: m_ActionsTags) {
        m_TagToAction[i.second] = i.first;
        m_ActionToTag[i.first]  = i.second;
    }
    
    NSString *defaults_fn = [NSBundle.mainBundle pathForResource:@"ShortcutsDefaults" ofType:@"plist"];
    ReadDefaults([NSArray arrayWithContentsOfFile:defaults_fn]);
    
    MigrateExternalPlistIfAny();
    
    if(NSArray *overrides = [NSUserDefaults.standardUserDefaults objectForKey:g_OverridesDefaultsKey])
        ReadOverrides(overrides);
}

ActionsShortcutsManager &ActionsShortcutsManager::Instance()
{
    static ActionsShortcutsManager *manager = new ActionsShortcutsManager;
    return *manager;
}

int ActionsShortcutsManager::TagFromAction(const string &_action) const
{
    for(auto &i: m_ActionsTags)
        if(i.first == _action)
            return i.second;
    return -1;
}

string ActionsShortcutsManager::ActionFromTag(int _tag) const
{
    for(auto &i: m_ActionsTags)
        if(i.second == _tag)
            return i.first;
    return "";
}

void ActionsShortcutsManager::ReadDefaults(NSArray *_dict)
{
    m_ShortCutsDefaults.clear();
    if(_dict.count % 2 != 0)
        return;

    for(int ind = 0; ind < _dict.count; ind += 2)
    {
        NSString *key = [_dict objectAtIndex:ind];
        NSString *obj = [_dict objectAtIndex:ind+1];
        
        auto i = m_ActionToTag.find(key.UTF8String);
        if(i == m_ActionToTag.end())
            continue;
        
        ShortCut sc;
        if(sc.FromPersString(obj))
            m_ShortCutsDefaults[i->second] = sc;
    }
}

void ActionsShortcutsManager::WriteDefaults(NSMutableArray *_dict) const
{
    for(auto &i: m_ActionsTags)
    {
        [_dict addObject:[NSString stringWithUTF8String:i.first.c_str()]];
        
        int tag = i.second;
        
        auto sc = m_ShortCutsDefaults.find(tag);
        if(sc != m_ShortCutsDefaults.end())
            [_dict addObject:sc->second.ToPersString()];
        else
            [_dict addObject:@""];
    }
}

void ActionsShortcutsManager::SetMenuShortCuts(NSMenu *_menu) const
{
    NSArray *array = _menu.itemArray;
    for(NSMenuItem *i: array)
    {
        if(i.submenu != nil)
        {
            SetMenuShortCuts(i.submenu);
        }
        else
        {
            int tag = (int)i.tag;

            auto scover = m_ShortCutsOverrides.find(tag);
            if(scover != m_ShortCutsOverrides.end())
            {
                i.keyEquivalent = scover->second.key;
                i.keyEquivalentModifierMask = scover->second.modifiers;
            }
            else
            {
                auto sc = m_ShortCutsDefaults.find(tag);
                if(sc != m_ShortCutsDefaults.end())
                {
                    i.keyEquivalent = sc->second.key;
                    i.keyEquivalentModifierMask = sc->second.modifiers;
                }
                else if(m_TagToAction.find(tag) != m_TagToAction.end())
                {
                    i.keyEquivalent = @"";
                    i.keyEquivalentModifierMask = 0;
                }
            }
        }
    }
}

void ActionsShortcutsManager::ReadOverrides(NSArray *_dict)
{
    m_ShortCutsOverrides.clear();
    
    if(_dict.count % 2 != 0)
        return;

    for(int ind = 0; ind < _dict.count; ind += 2)
    {
        NSString *key = [_dict objectAtIndex:ind];
        NSString *obj = [_dict objectAtIndex:ind+1];

        auto i = m_ActionToTag.find(key.UTF8String);
        if(i == m_ActionToTag.end())
            continue;
        
        if([obj isEqualToString:@"default"])
            continue;
        
        ShortCut sc;
        if(sc.FromPersString(obj))
            m_ShortCutsOverrides[i->second] = sc;
    }
}

void ActionsShortcutsManager::WriteOverrides(NSMutableArray *_dict) const
{
    for(auto &i: m_ActionsTags) {
        int tag = i.second;
        auto scover = m_ShortCutsOverrides.find(tag);
        if(scover != m_ShortCutsOverrides.end()) {
            [_dict addObject:[NSString stringWithUTF8String:i.first.c_str()]];
            [_dict addObject:scover->second.ToPersString()];
        }
    }
}

const ActionsShortcutsManager::ShortCut *ActionsShortcutsManager::ShortCutFromAction(const string &_action) const
{
    int tag = TagFromAction(_action);
    if(tag <= 0)
        return nullptr;
    auto sc_override = m_ShortCutsOverrides.find(tag);
    if(sc_override != m_ShortCutsOverrides.end())
        return &sc_override->second;
    
    auto sc_default = m_ShortCutsDefaults.find(tag);
    if(sc_default != m_ShortCutsDefaults.end())
        return &sc_default->second;
    
    return nullptr;
}

const ActionsShortcutsManager::ShortCut *ActionsShortcutsManager::ShortCutFromTag(int _tag) const
{
    auto sc_override = m_ShortCutsOverrides.find(_tag);
    if(sc_override != m_ShortCutsOverrides.end())
        return &sc_override->second;
    
    auto sc_default = m_ShortCutsDefaults.find(_tag);
    if(sc_default != m_ShortCutsDefaults.end())
        return &sc_default->second;
    
    return nullptr;
}

void ActionsShortcutsManager::SetShortCutOverride(const string &_action, const ShortCut& _sc)
{
    int tag = TagFromAction(_action);
    if(tag <= 0)
        return;
    
    auto &orig = m_ShortCutsDefaults[tag];
    if(orig == _sc) {
        m_ShortCutsOverrides.erase(tag);
        return;
    }
    m_ShortCutsOverrides[tag] = _sc;
    
    // immediately write to NSUserDefaults
    WriteOverridesToNSDefaults();
}

void ActionsShortcutsManager::RevertToDefaults()
{
    m_ShortCutsOverrides.clear();
    WriteOverridesToNSDefaults();
}

void ActionsShortcutsManager::MigrateExternalPlistIfAny()
{
    NSArray *old = [NSArray arrayWithContentsOfFile:OverridesFullPathOld()];
    if(!old)
        return;
    if(old.count % 2 != 0)
        return;

    // store backup of migrated plist
    rename(OverridesFullPathOld().UTF8String, [NSString stringWithFormat:@"%@_old", OverridesFullPathOld()].UTF8String);
    
    m_ShortCutsOverrides.clear();
    for(int ind = 0; ind < old.count; ind += 2) {
        NSString *key = [old objectAtIndex:ind];
        NSString *obj = [old objectAtIndex:ind+1];
        
        auto i = m_ActionToTag.find(key.UTF8String);
        if(i == m_ActionToTag.end())
            continue;
        
        if([obj isEqualToString:@"default"])
            continue;
        
        ShortCut sc;
        if(sc.FromPersString(obj))
            m_ShortCutsOverrides[i->second] = sc;
    }

    // and then write overrides to defaults
    WriteOverridesToNSDefaults();
    
    m_ShortCutsOverrides.clear();
}

void ActionsShortcutsManager::WriteOverridesToNSDefaults() const
{
    NSMutableArray *overrides = [NSMutableArray new];
    WriteOverrides(overrides);
    
    [NSUserDefaults.standardUserDefaults setObject:overrides forKey:g_OverridesDefaultsKey];
}
