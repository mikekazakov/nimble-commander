// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ActionShortcut.h"
#include <locale>
#include <vector>
#include <codecvt>
#include <unordered_map>
#include <Carbon/Carbon.h>

namespace nc::utility {

static_assert(sizeof(ActionShortcut) == 4);

ActionShortcut::ActionShortcut(const std::string &_from) noexcept : ActionShortcut(_from.c_str())
{
}

ActionShortcut::ActionShortcut(const char *_from) noexcept
    : // construct from persistency string
      ActionShortcut()
{
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
    std::u16string utf16 = convert.from_bytes(_from);
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
                unicode = (uint16_t)towlower(v.front());
            break;
        }
        v.remove_prefix(1);
    }
    modifiers = mod_flags;
}

ActionShortcut::ActionShortcut(const char8_t *_from) noexcept
    : ActionShortcut(reinterpret_cast<const char *>(_from))
{
}

ActionShortcut::ActionShortcut(uint16_t _unicode, unsigned long long _modif) noexcept
    : unicode(_unicode), modifiers(0)
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

ActionShortcut::operator bool() const noexcept
{
    return unicode != 0;
}

std::string ActionShortcut::ToPersString() const noexcept
{
    std::string result;
    if( modifiers & NSEventModifierFlagShift )
        result += reinterpret_cast<const char *>(u8"⇧");
    if( modifiers & NSEventModifierFlagControl )
        result += reinterpret_cast<const char *>(u8"^");
    if( modifiers & NSEventModifierFlagOption )
        result += reinterpret_cast<const char *>(u8"⌥");
    if( modifiers & NSEventModifierFlagCommand )
        result += reinterpret_cast<const char *>(u8"⌘");

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
    if( NSString *key = [NSString stringWithCharacters:&unicode length:1] )
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

[[clang::no_destroy]] static const std::unordered_map<uint16_t, NSString *> g_UnicodeToNiceString =
{
    {NSLeftArrowFunctionKey, @"←"},
    {NSRightArrowFunctionKey, @"→"},
    {NSDownArrowFunctionKey, @"↓"},
    {NSUpArrowFunctionKey, @"↑"},
    {NSF1FunctionKey, @"F1"},
    {NSF2FunctionKey, @"F2"},
    {NSF3FunctionKey, @"F3"},
    {NSF4FunctionKey, @"F4"},
    {NSF5FunctionKey, @"F5"},
    {NSF6FunctionKey, @"F6"},
    {NSF7FunctionKey, @"F7"},
    {NSF8FunctionKey, @"F8"},
    {NSF9FunctionKey, @"F9"},
    {NSF10FunctionKey, @"F10"},
    {NSF11FunctionKey, @"F11"},
    {NSF12FunctionKey, @"F12"},
    {NSF13FunctionKey, @"F13"},
    {NSF14FunctionKey, @"F14"},
    {NSF15FunctionKey, @"F15"},
    {NSF16FunctionKey, @"F16"},
    {NSF17FunctionKey, @"F17"},
    {NSF18FunctionKey, @"F18"},
    {NSF19FunctionKey, @"F19"},
    {0x2326, @"⌦"},
    {'\r', @"↩"},
    {0x3, @"⌅"},
    {0x9, @"⇥"},
    {0x2423, @"Space"},
    {0x0020, @"Space"},
    {0x8, @"⌫"},
    {NSClearDisplayFunctionKey, @"Clear"},
    {0x1B, @"⎋"},
    {NSHomeFunctionKey, @"↖"},
    {NSPageUpFunctionKey, @"⇞"},
    {NSEndFunctionKey, @"↘"},
    {NSPageDownFunctionKey, @"⇟"},
    {NSHelpFunctionKey, @"Help"}};

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

bool ActionShortcut::IsKeyDown(uint16_t _unicode, unsigned long long _modifiers) const noexcept
{
    if( !unicode )
        return false;

    // exclude CapsLock/NumPad/Func from our decision process
    constexpr auto mask = NSEventModifierFlagDeviceIndependentFlagsMask &
                          (~NSEventModifierFlagCapsLock & ~NSEventModifierFlagNumericPad &
                           ~NSEventModifierFlagFunction);
    auto clean_modif = _modifiers & mask;

    if( unicode >= 32 && unicode < 128 && modifiers.is_empty() )
        clean_modif &=
            ~NSEventModifierFlagShift; // some chars were produced by pressing key with shift

    if( modifiers == NSEventModifierFlagsHolder{clean_modif} && unicode == _unicode )
        return true;

    if( modifiers.is_shift() && modifiers == NSEventModifierFlagsHolder{clean_modif} ) {
        if( unicode >= 97 && unicode <= 125 && unicode == _unicode + 32 )
            return true;
        if( unicode >= 65 && unicode <= 93 && unicode + 32 == _unicode )
            return true;
    }

    return false;
}

bool ActionShortcut::operator==(const ActionShortcut &_rhs) const noexcept
{
    return modifiers == _rhs.modifiers && unicode == _rhs.unicode;
}

bool ActionShortcut::operator!=(const ActionShortcut &_rhs) const noexcept
{
    return !(*this == _rhs);
}

}

size_t std::hash<nc::utility::ActionShortcut>::operator()(
    const nc::utility::ActionShortcut &_ac) const noexcept
{
    return ((size_t)_ac.unicode) | (((size_t)_ac.modifiers.flags) << 16);
}
