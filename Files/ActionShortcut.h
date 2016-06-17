#pragma once

struct ActionShortcut
{
    ActionShortcut();
    ActionShortcut(NSString *_from); // construct from persistency string
    ActionShortcut(uint16_t  _unicode, unsigned long _modif); // construct from straight data
    ActionShortcut(NSString *_from, unsigned long _modif); // construct from string and modifiers
    
    bool operator ==(const ActionShortcut&_r) const;
    bool operator !=(const ActionShortcut&_r) const;
    operator    bool() const;
    
    NSString   *Key() const;
    NSString   *ToPersString() const;
    bool        IsKeyDown(uint16_t _unicode, uint16_t _keycode, uint64_t _modifiers) const noexcept;
    
    uint16_t        unicode;
    uint64_t        modifiers;
};