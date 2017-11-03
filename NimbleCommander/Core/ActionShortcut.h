// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/NSEventModifierFlagsHolder.h>

struct ActionShortcut
{
    ActionShortcut();
    ActionShortcut(const string& _from); // construct from persistency string, utf8
    ActionShortcut(const char* _from); // construct from persistency string
    ActionShortcut(uint16_t  _unicode, unsigned long _modif); // construct from straight data
    
    bool operator ==(const ActionShortcut &_rhs) const;
    bool operator !=(const ActionShortcut &_rhs) const;
    operator    bool() const;

#ifdef __OBJC__
    NSString   *Key() const;
    NSString   *PrettyString() const;
#endif
    string      ToPersString() const;
    bool        IsKeyDown(uint16_t _unicode, uint64_t _modifiers) const noexcept;
    
    uint16_t                    unicode;
    NSEventModifierFlagsHolder  modifiers;
};

template<>
struct std::hash<ActionShortcut>
{
    size_t operator()(const ActionShortcut&) const noexcept;
};
