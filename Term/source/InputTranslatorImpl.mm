// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InputTranslatorImpl.h"
#include <cassert>
#include <Carbon/Carbon.h>

namespace nc::term{

static CFStringRef CreateModifiedCharactersForKeyPress(unsigned short _keycode,
                                                       NSEventModifierFlags _flags);

void InputTranslatorImpl::SetOuput( Output _output )
{
    m_Output = std::move(_output);
}

void InputTranslatorImpl::ProcessKeyDown( NSEvent *_event )
{
    assert( m_Output );
    assert( _event );

    NSString* character = _event.charactersIgnoringModifiers;
     if( character.length != 1 )
         return;
     
     const uint16_t unicode = [character characterAtIndex:0];
     const auto modflags = _event.modifierFlags;
    
     const char *seq_resp = nullptr;
     switch( unicode ){
         case NSUpArrowFunctionKey:      seq_resp = m_ApplicationCursorKeys ? "\eOA" : "\e[A"; break;
         case NSDownArrowFunctionKey:    seq_resp = m_ApplicationCursorKeys ? "\eOB" : "\e[B"; break;
         case NSRightArrowFunctionKey:   seq_resp = m_ApplicationCursorKeys ? "\eOC" : "\e[C"; break;
         case NSLeftArrowFunctionKey:    seq_resp = m_ApplicationCursorKeys ? "\eOD" : "\e[D"; break;
         case NSF1FunctionKey:           seq_resp = "\eOP";      break;
         case NSF2FunctionKey:           seq_resp = "\eOQ";      break;
         case NSF3FunctionKey:           seq_resp = "\eOR";      break;
         case NSF4FunctionKey:           seq_resp = "\eOS";      break;
         case NSF5FunctionKey:           seq_resp = "\e[15~";    break;
         case NSF6FunctionKey:           seq_resp = "\e[17~";    break;
         case NSF7FunctionKey:           seq_resp = "\e[18~";    break;
         case NSF8FunctionKey:           seq_resp = "\e[19~";    break;
         case NSF9FunctionKey:           seq_resp = "\e[20~";    break;
         case NSF10FunctionKey:          seq_resp = "\e[21~";    break;
         case NSF11FunctionKey:          seq_resp = "\e[23~";    break;
         case NSF12FunctionKey:          seq_resp = "\e[24~";    break;
         case NSHomeFunctionKey:         seq_resp = "\eOH";      break;
         case NSInsertFunctionKey:       seq_resp = "\e[2~";     break;
         case NSDeleteFunctionKey:       seq_resp = "\e[3~";     break;
         case NSEndFunctionKey:          seq_resp = "\eOF";      break;
         case NSPageUpFunctionKey:       seq_resp = "\e[5~";     break;
         case NSPageDownFunctionKey:     seq_resp = "\e[6~";     break;
         case 9: /* tab */
             if (modflags & NSShiftKeyMask) /* do we really getting these messages? */
                 seq_resp = "\e[Z";
             else
                 seq_resp = "\011";
             break;
     }
     
     if( seq_resp ) {
         m_Output( Bytes( (std::byte*)seq_resp, strlen(seq_resp)) );
         return;
     }
     
     // process regular keys down
     if( modflags & NSControlKeyMask ) {
         unsigned short cc = 0xFFFF;
         if (unicode >= 'a' && unicode <= 'z')                           cc = unicode - 'a' + 1;
         else if (unicode == ' ' || unicode == '2' || unicode == '@')    cc = 0;
         else if (unicode == '[')                                        cc = 27;
         else if (unicode == '\\')                                       cc = 28;
         else if (unicode == ']')                                        cc = 29;
         else if (unicode == '^' || unicode == '6')                      cc = 30;
         else if (unicode == '-' || unicode == '_')                      cc = 31;
         m_Output( Bytes((std::byte*)&cc, 1) );
         return;
     }

     if( modflags & NSAlternateKeyMask )
         character = (NSString*)CFBridgingRelease(CreateModifiedCharactersForKeyPress(_event.keyCode,
                                                                                      modflags) );
     else if( (modflags&NSDeviceIndependentModifierFlagsMask) == NSAlphaShiftKeyMask )
         character = _event.characters;
     
     const char* utf8 = character.UTF8String;
    m_Output( Bytes((std::byte*)utf8, strlen(utf8)) );
}

void InputTranslatorImpl::ProcessTextInput(NSString *_str)
{
    if(!_str || _str.length == 0)
        return;
    
    const char* utf8str = [_str UTF8String];
    size_t sz = strlen(utf8str);

    m_Output( Bytes((std::byte*)utf8str, sz) );
}

void InputTranslatorImpl::SetApplicationCursorKeys( bool _enabled )
{
    m_ApplicationCursorKeys = _enabled;    
}

/**
 * That's a hacky implementation, it mimicks the real deadKeyState.
 * This can serve for purposes of decoding a single option-modified keypress, but can't be used for double keys decoding
 */
static CFStringRef CreateModifiedCharactersForKeyPress(unsigned short _keycode, NSEventModifierFlags _flags)
{
    // http://stackoverflow.com/questions/12547007/convert-key-code-into-key-equivalent-string
    // http://stackoverflow.com/questions/8263618/convert-virtual-key-code-to-unicode-string
    // http://stackoverflow.com/questions/22566665/how-to-capture-unicode-from-key-events-without-an-nstextview
    
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    const UInt8 kbdType = LMGetKbdType();
    const UInt32 modifierKeyState = (_flags >> 16) & 0xFF;
    
    UInt32 deadKeyState = 0;
    const size_t unicodeStringLength = 4;
    UniChar unicodeString[unicodeStringLength];
    UniCharCount realLength;
    
    UCKeyTranslate(keyboardLayout,
                   _keycode,
                   kUCKeyActionDown,
                   modifierKeyState,
                   kbdType,
                   0,
                   &deadKeyState,
                   unicodeStringLength,
                   &realLength,
                   unicodeString);
    UCKeyTranslate(keyboardLayout,
                   _keycode,
                   kUCKeyActionDown,
                   modifierKeyState,
                   kbdType,
                   0,
                   &deadKeyState,
                   unicodeStringLength,
                   &realLength,
                   unicodeString);
    CFRelease(currentKeyboard);
    return CFStringCreateWithCharacters(kCFAllocatorDefault, unicodeString, realLength);
}

}

