// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/NSEventModifierFlagsHolder.h>
#include <string>
#include <functional>
#include <stdint.h>

#ifdef __OBJC__
    #include <Foundation/Foundation.h>
#endif

namespace nc::utility {

struct ActionShortcut
{
    ActionShortcut() noexcept = default;
    
    // construct from persistency string, utf8
    ActionShortcut(const std::string& _from) noexcept; 
    
    // construct from persistency string
    ActionShortcut(const char* _from) noexcept; 
    
    // construct from straight data
    ActionShortcut(unsigned short  _unicode, unsigned long long _modif) noexcept; 
    
    bool operator ==(const ActionShortcut &_rhs) const noexcept;
    bool operator !=(const ActionShortcut &_rhs) const noexcept;
    operator    bool() const noexcept;

#ifdef __OBJC__
    NSString   *Key() const noexcept;
    NSString   *PrettyString() const noexcept;
#endif
    std::string ToPersString() const noexcept;
    bool        IsKeyDown(uint16_t _unicode, unsigned long long _modifiers) const noexcept;
    
    unsigned short              unicode = 0;
    NSEventModifierFlagsHolder  modifiers = 0;
};

}

template<>
struct std::hash<nc::utility::ActionShortcut>
{
    size_t operator()(const nc::utility::ActionShortcut&) const noexcept;
};
