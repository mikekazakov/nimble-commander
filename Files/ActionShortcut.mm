#include "ActionShortcut.h"

ActionShortcut::ActionShortcut():
    unicode(0),
    modifiers(0)
{
}

ActionShortcut::ActionShortcut(NSString *_from) :
    ActionShortcut()
{
    if( _from == nil || _from.length == 0 )
        return;
    
    int len = (int)_from.length;
    unsigned mod_ = 0;
    NSString *key_ = nil;
    for( int i = 0; i < len; ++i ) {
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
        return;
    
    if([key_ isEqualToString:@"\\r"])
        key_ = @"\r";
    else if([key_ isEqualToString:@"\\t"])
        key_ = @"\t";
    
    modifiers = mod_;
    unicode = [key_ characterAtIndex:0];
}

ActionShortcut::ActionShortcut(uint16_t  _unicode, unsigned long _modif)
{
    unicode = _unicode;
    modifiers = 0;
    if(_modif & NSShiftKeyMask)     modifiers |= NSShiftKeyMask;
    if(_modif & NSControlKeyMask)   modifiers |= NSControlKeyMask;
    if(_modif & NSAlternateKeyMask) modifiers |= NSAlternateKeyMask;
    if(_modif & NSCommandKeyMask)   modifiers |= NSCommandKeyMask;
}

ActionShortcut::ActionShortcut(NSString *_from, unsigned long _modif):
    ActionShortcut( (_from != nil && _from.length != 0) ? [_from characterAtIndex:0] : 0, _modif)
{
}

ActionShortcut::operator bool() const
{
    return unicode != 0;
}


NSString *ActionShortcut::ToPersString() const
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
    
    if( NSString *key = [NSString stringWithCharacters:&unicode length:1] ) {
        NSString *str = key;
        if([str isEqualToString:@"\r"])
            str = @"\\r";
        
        result = [result stringByAppendingString:str];
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
