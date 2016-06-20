#include <locale>
#include <codecvt>
#include "ActionShortcut.h"

ActionShortcut::ActionShortcut():
    unicode(0),
    modifiers(0)
{
}

ActionShortcut::ActionShortcut(const string& _from):
    ActionShortcut(_from.c_str())
{
}

ActionShortcut::ActionShortcut(const char* _from): // construct from persistency string
    ActionShortcut()
{
    wstring_convert<codecvt_utf8_utf16<char16_t>, char16_t> convert;
    u16string utf16 = convert.from_bytes(_from);
    u16string_view v(utf16);
    while( !v.empty() ) {
        auto c = v.front();
        if( c == u'⇧' )
            modifiers |= NSShiftKeyMask;
        else if( c == u'^' )
            modifiers |= NSControlKeyMask;
        else if( c == u'⌥' )
            modifiers |= NSAlternateKeyMask;
        else if( c == u'⌘' )
            modifiers |= NSCommandKeyMask;
        else {
            if( v == u"\\r" )
                unicode = '\r';
            else if( v == u"\\t" )
                unicode = '\t';
            else
                unicode = v.front();
            break;
        }
        v.remove_prefix(1);
    }
}

ActionShortcut::ActionShortcut(uint16_t _unicode, unsigned long _modif):
    unicode(_unicode),
    modifiers(0)
{
    if(_modif & NSShiftKeyMask)     modifiers |= NSShiftKeyMask;
    if(_modif & NSControlKeyMask)   modifiers |= NSControlKeyMask;
    if(_modif & NSAlternateKeyMask) modifiers |= NSAlternateKeyMask;
    if(_modif & NSCommandKeyMask)   modifiers |= NSCommandKeyMask;
}

ActionShortcut::operator bool() const
{
    return unicode != 0;
}

string ActionShortcut::ToPersString() const
{
    string result;
    if( modifiers & NSShiftKeyMask )
        result += u8"⇧";
    if( modifiers & NSControlKeyMask )
        result += u8"^";
    if( modifiers & NSAlternateKeyMask )
        result += u8"⌥";
    if( modifiers & NSCommandKeyMask )
        result += u8"⌘";
    
    if( unicode == '\r' )
        result += "\\r";
    else if( unicode == '\t' )
        result += "\\t";
    else {
        u16string key_utf16;
        key_utf16.push_back(unicode);
        wstring_convert<codecvt_utf8_utf16<char16_t>,char16_t> convert;
        result += convert.to_bytes(key_utf16);
    }
    
    return result;
}

NSString *ActionShortcut::Key() const
{
    if( NSString *key = [NSString stringWithCharacters:&unicode length:1] )
        return key;
    return @"";
}

bool ActionShortcut::IsKeyDown(uint16_t _unicode, uint16_t _keycode, uint64_t _modifiers) const noexcept
{
    // exclude CapsLock/NumPad/Func from our decision process
    unsigned long clean_modif = _modifiers &
    (NSDeviceIndependentModifierFlagsMask & (~NSAlphaShiftKeyMask & ~NSNumericPadKeyMask & ~NSFunctionKeyMask) );
    
    if( unicode >= 32 && unicode < 128 && modifiers == 0 )
        clean_modif &= ~NSShiftKeyMask; // some chars were produced by pressing key with shift
        
    return modifiers == clean_modif && unicode == _unicode;
}

bool ActionShortcut::operator==(const ActionShortcut&_r) const
{
    if(modifiers != _r.modifiers)
        return false;
    if(unicode != _r.unicode)
        return false;
    return true;
}

bool ActionShortcut::operator!=(const ActionShortcut&_r) const
{
    return !(*this == _r);
}
