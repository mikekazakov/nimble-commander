// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#define _LIBCPP_DISABLE_DEPRECATION_WARNINGS 1
#include "ActionShortcut.h"
#include <locale>
#include <vector>
#include <codecvt>
#include <unordered_map>
#include <ankerl/unordered_dense.h>
#include <Base/ToLower.h>
#include <Carbon/Carbon.h>

namespace nc::utility {

static_assert(sizeof(ActionShortcut) == 4);
static_assert(std::is_trivially_copyable_v<ActionShortcut>);
static_assert(std::is_trivially_destructible_v<ActionShortcut>);
static_assert(std::is_trivially_copy_assignable_v<ActionShortcut>);

ActionShortcut::EventData::EventData(unsigned short _chmod,
                                     unsigned short _chunmod,
                                     unsigned short _kc,
                                     unsigned long _mods) noexcept
    : char_with_modifiers(_chmod), char_without_modifiers(_chunmod), key_code(_kc), modifiers(_mods)
{
}

ActionShortcut::EventData::EventData(NSEvent *_event) noexcept
{
    assert(_event != nil);
    assert(_event.type == NSEventTypeKeyDown);

    const auto chars_with_mods = _event.characters;
    char_with_modifiers = chars_with_mods.length > 0 ? [chars_with_mods characterAtIndex:0] : 0;

    const auto chars_without_mods = _event.charactersIgnoringModifiers;
    char_without_modifiers = chars_without_mods.length > 0 ? [chars_without_mods characterAtIndex:0] : 0;

    key_code = _event.keyCode;
    modifiers = _event.modifierFlags;
}

ActionShortcut::ActionShortcut(std::string_view _from) noexcept : ActionShortcut()
{
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
    const std::u16string utf16 = convert.from_bytes(_from.data(), _from.data() + _from.length());
    std::u16string_view v(utf16);
    uint64_t mod_flags = 0;
    while( !v.empty() ) {
        auto c = v.front();
        if( c == u'⇧' )
            mod_flags |= NSEventModifierFlagShift;
        else if( c == u'^' )
            mod_flags |= NSEventModifierFlagControl;
        else if( c == u'⌥' )
            mod_flags |= NSEventModifierFlagOption;
        else if( c == u'⌘' )
            mod_flags |= NSEventModifierFlagCommand;
        else {
            if( v == u"\\r" )
                unicode = '\r';
            else if( v == u"\\t" )
                unicode = '\t';
            else
                unicode = static_cast<uint16_t>(std::towlower(v.front()));
            break;
        }
        v.remove_prefix(1);
    }
    modifiers = mod_flags;
}

ActionShortcut::ActionShortcut(uint16_t _unicode, unsigned long long _modif) noexcept : unicode(_unicode), modifiers(0)
{
    uint64_t mod_flags = 0;
    if( _modif & NSEventModifierFlagShift )
        mod_flags |= NSEventModifierFlagShift;
    if( _modif & NSEventModifierFlagControl )
        mod_flags |= NSEventModifierFlagControl;
    if( _modif & NSEventModifierFlagOption )
        mod_flags |= NSEventModifierFlagOption;
    if( _modif & NSEventModifierFlagCommand )
        mod_flags |= NSEventModifierFlagCommand;
    modifiers = mod_flags;
}

ActionShortcut::ActionShortcut(const EventData &_event) noexcept
{
    // Exclude CapsLock/NumPad/Func from our decision process - our hotkeys don't support these modifiers.
    constexpr auto mask =
        NSEventModifierFlagDeviceIndependentFlagsMask &
        (~NSEventModifierFlagCapsLock & ~NSEventModifierFlagNumericPad & ~NSEventModifierFlagFunction);
    modifiers = NSEventModifierFlagsHolder{_event.modifiers & mask};

    // When the shift modifier is present, characters are shown as UPPERCASE even when explicitly asked to provide them
    // without modifiers. Explicitly remove this by lowercasing the input character.
    unicode = nc::base::g_ToLower[_event.char_without_modifiers];
}

ActionShortcut::operator bool() const noexcept
{
    return unicode != 0;
}

std::string ActionShortcut::ToPersString() const noexcept
{
    std::string result;
    if( modifiers & NSEventModifierFlagShift )
        result += "⇧";
    if( modifiers & NSEventModifierFlagControl )
        result += "^";
    if( modifiers & NSEventModifierFlagOption )
        result += "⌥";
    if( modifiers & NSEventModifierFlagCommand )
        result += "⌘";

    if( unicode == '\r' )
        result += "\\r";
    else if( unicode == '\t' )
        result += "\\t";
    else {
        std::u16string key_utf16;
        key_utf16.push_back(unicode);
        std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
        result += convert.to_bytes(key_utf16);
    }

    return result;
}

NSString *ActionShortcut::Key() const noexcept
{
    if( !*this )
        return @"";
    if( NSString *const key = [NSString stringWithCharacters:&unicode length:1] )
        return key;
    return @"";
}

static NSString *StringForModifierFlags(uint64_t flags)
{
    UniChar modChars[4]; // We only look for 4 flags
    unsigned int charCount = 0;
    // These are in the same order as the menu manager shows them
    if( flags & NSEventModifierFlagControl )
        modChars[charCount++] = kControlUnicode;
    if( flags & NSEventModifierFlagOption )
        modChars[charCount++] = kOptionUnicode;
    if( flags & NSEventModifierFlagShift )
        modChars[charCount++] = kShiftUnicode;
    if( flags & NSEventModifierFlagCommand )
        modChars[charCount++] = kCommandUnicode;
    if( charCount == 0 )
        return @"";

    return [NSString stringWithCharacters:modChars length:charCount];
}

[[clang::no_destroy]] static const ankerl::unordered_dense::map<uint32_t, NSString *> g_UnicodeToNiceString = {
    {NSLeftArrowFunctionKey, @"←"},        //
    {NSRightArrowFunctionKey, @"→"},       //
    {NSDownArrowFunctionKey, @"↓"},        //
    {NSUpArrowFunctionKey, @"↑"},          //
    {NSF1FunctionKey, @"F1"},              //
    {NSF2FunctionKey, @"F2"},              //
    {NSF3FunctionKey, @"F3"},              //
    {NSF4FunctionKey, @"F4"},              //
    {NSF5FunctionKey, @"F5"},              //
    {NSF6FunctionKey, @"F6"},              //
    {NSF7FunctionKey, @"F7"},              //
    {NSF8FunctionKey, @"F8"},              //
    {NSF9FunctionKey, @"F9"},              //
    {NSF10FunctionKey, @"F10"},            //
    {NSF11FunctionKey, @"F11"},            //
    {NSF12FunctionKey, @"F12"},            //
    {NSF13FunctionKey, @"F13"},            //
    {NSF14FunctionKey, @"F14"},            //
    {NSF15FunctionKey, @"F15"},            //
    {NSF16FunctionKey, @"F16"},            //
    {NSF17FunctionKey, @"F17"},            //
    {NSF18FunctionKey, @"F18"},            //
    {NSF19FunctionKey, @"F19"},            //
    {0x2326, @"⌦"},                        // TODO: verify!
    {0x7F28, @"⌦"},                        //
    {'\r', @"↩"},                          //
    {0x3, @"⌅"},                           //
    {NSTabCharacter, @"⇥"},                //
    {0x2423, @"Space"},                    //
    {0x0020, @"Space"},                    //
    {NSBackspaceCharacter, @"⌫"},          //
    {NSDeleteCharacter, @"⌫"},             //
    {NSClearDisplayFunctionKey, @"Clear"}, //
    {0x1B, @"⎋"},                          //
    {NSHomeFunctionKey, @"↖"},             //
    {NSPageUpFunctionKey, @"⇞"},           //
    {NSEndFunctionKey, @"↘"},              //
    {NSPageDownFunctionKey, @"⇟"},         //
    {NSHelpFunctionKey, @"Help"}           //
};

NSString *ActionShortcut::PrettyString() const noexcept
{
    if( !*this )
        return @"";

    NSString *vis_key;
    if( auto it = g_UnicodeToNiceString.find(unicode); it != std::end(g_UnicodeToNiceString) )
        vis_key = it->second;
    else
        vis_key = Key().uppercaseString;

    if( modifiers.is_empty() )
        return vis_key;
    else
        return [NSString stringWithFormat:@"%@%@", StringForModifierFlags(modifiers), vis_key];
}

} // namespace nc::utility

size_t std::hash<nc::utility::ActionShortcut>::operator()(const nc::utility::ActionShortcut &_ac) const noexcept
{
    return static_cast<size_t>(_ac.unicode) | (static_cast<size_t>(_ac.modifiers.flags) << 16);
}

@implementation NSMenuItem (ActionShortcutSupport)

- (void)nc_setKeyEquivalentWithShortcut:(nc::utility::ActionShortcut)_shortcut
{
    // https://developer.apple.com/documentation/appkit/nsmenuitem/1514842-keyequivalent?language=objc
    // If you want to specify the Backspace key as the key equivalent for a menu item, use a single character string
    // with NSBackspaceCharacter (defined in NSText.h as 0x08) and for the Forward Delete key, use NSDeleteCharacter
    // (defined in NSText.h as 0x7F). Note that these are not the same characters you get from an NSEvent key-down event
    // when pressing those keys.
    if( _shortcut.unicode == 0x007F ) {
        [self setKeyEquivalent:@"\u0008"]; // NSBackspaceCharacter
        [self setKeyEquivalentModifierMask:_shortcut.modifiers];
        return;
    }
    if( _shortcut.unicode == 0x7F28 ) {
        [self setKeyEquivalent:@"\u007f"]; // NSDeleteCharacter
        [self setKeyEquivalentModifierMask:_shortcut.modifiers];
        return;
    }
    [self setKeyEquivalent:_shortcut.Key()];
    [self setKeyEquivalentModifierMask:_shortcut.modifiers];
}

@end
