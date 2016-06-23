#pragma once

struct ActionShortcut
{
    ActionShortcut();
    ActionShortcut(const string& _from); // construct from persistency string, utf8
    ActionShortcut(const char* _from); // construct from persistency string
    ActionShortcut(uint16_t  _unicode, unsigned long _modif); // construct from straight data
    
    bool operator ==(const ActionShortcut&_r) const;
    bool operator !=(const ActionShortcut&_r) const;
    operator    bool() const;

#ifdef __OBJC__
    NSString   *Key() const;
#endif
    string      ToPersString() const;
    bool        IsKeyDown(uint16_t _unicode, uint16_t _keycode, uint64_t _modifiers) const noexcept;
    
    uint16_t        unicode;
    uint64_t        modifiers;
};
