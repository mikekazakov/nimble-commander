//
//  ActionsShortcutsManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "ActionsShortcutsManager.h"

static NSString *g_OverridesFilename = @"/shortcuts.plist";

NSString *ActionsShortcutsManager::ShortCut::ToString() const
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

bool ActionsShortcutsManager::ShortCut::FromString(NSString *_from)
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

ActionsShortcutsManager::ActionsShortcutsManager()
{
    for(auto &i: m_ActionsTags)
    {
        m_TagToAction[i.second] = i.first;
        m_ActionToTag[i.first]  = i.second;
    }
}

ActionsShortcutsManager &ActionsShortcutsManager::Instance()
{
    static ActionsShortcutsManager *manager = nullptr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = new ActionsShortcutsManager;
    });
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
        if(sc.FromString(obj))
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
            [_dict addObject:sc->second.ToString()];
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
                [i setKeyEquivalent:scover->second.key];
                [i setKeyEquivalentModifierMask:scover->second.modifiers];
            }
            else
            {
                auto sc = m_ShortCutsDefaults.find(tag);
                if(sc != m_ShortCutsDefaults.end())
                {
                    [i setKeyEquivalent:sc->second.key];
                    [i setKeyEquivalentModifierMask:sc->second.modifiers];
                }
                else if(m_TagToAction.find(tag) != m_TagToAction.end())
                {
                    [i setKeyEquivalent:@""];
                    [i setKeyEquivalentModifierMask:0];
                }
            }
        }
    }
}

void ActionsShortcutsManager::ReadOverrides(NSArray *_dict)
{
    if(_dict.count % 2 != 0)
        return;
    int total_actions_read = 0;
    m_ShortCutsOverrides.clear();
    for(int ind = 0; ind < _dict.count; ind += 2)
    {
        NSString *key = [_dict objectAtIndex:ind];
        NSString *obj = [_dict objectAtIndex:ind+1];

        auto i = m_ActionToTag.find(key.UTF8String);
        if(i == m_ActionToTag.end())
            continue;
        
        if([obj isEqualToString:@"default"])
        {
            total_actions_read++;
            continue;
        }
        
        ShortCut sc;
        if(sc.FromString(obj))
        {
            m_ShortCutsOverrides[i->second] = sc;
            total_actions_read++;
        }
    }
    
    if(total_actions_read < m_ActionsTags.size())
        m_OutDatedOverrides = true;
}

bool ActionsShortcutsManager::NeedToUpdateOverrides() const
{
    return m_OutDatedOverrides;
}

void ActionsShortcutsManager::WriteOverrides(NSMutableArray *_dict) const
{
    for(auto &i: m_ActionsTags)
    {
        [_dict addObject:[NSString stringWithUTF8String:i.first.c_str()]];
        
        int tag = i.second;
        
        auto scover = m_ShortCutsOverrides.find(tag);
        if(scover != m_ShortCutsOverrides.end())
        {
            [_dict addObject:scover->second.ToString()];
        }
        else
        {
            auto scdef = m_ShortCutsDefaults.find(tag);
            if(scdef != m_ShortCutsDefaults.end())
                [_dict addObject:scdef->second.ToString()];
            else
                [_dict addObject:@"default"];
        }
    }
}

void ActionsShortcutsManager::DoInit()
{
    NSString *defaults_fn = [[NSBundle mainBundle] pathForResource:@"Shortcuts" ofType:@"plist"];
    ReadDefaults([NSArray arrayWithContentsOfFile:defaults_fn]);
    
    NSString *overrides_fn = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingString:g_OverridesFilename];
    ReadOverrides([NSArray arrayWithContentsOfFile:overrides_fn]);
    if(NeedToUpdateOverrides())
    {
        NSMutableArray *new_overrides = [NSMutableArray new];
        WriteOverrides(new_overrides);
        [new_overrides writeToFile:overrides_fn atomically:true];
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
