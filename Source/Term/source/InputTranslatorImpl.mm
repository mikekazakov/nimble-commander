// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InputTranslatorImpl.h"
#include <cassert>
#include <string>
#include <Carbon/Carbon.h>
#include <algorithm>

namespace nc::term {

static_assert(sizeof(InputTranslator::MouseEvent) == 8);

static CFStringRef CreateModifiedCharactersForKeyPress(unsigned short _keycode, NSEventModifierFlags _flags);
static std::string ReportX10(InputTranslator::MouseEvent _event) noexcept;
static std::string ReportNormal(InputTranslator::MouseEvent _event) noexcept;
static std::string ReportUTF8(InputTranslator::MouseEvent _event) noexcept;
static std::string ReportSGR(InputTranslator::MouseEvent _event) noexcept;

InputTranslatorImpl::InputTranslatorImpl() : m_MouseReportFormatter(ReportNormal)
{
}

void InputTranslatorImpl::SetOuput(Output _output)
{
    m_Output = std::move(_output);
}

void InputTranslatorImpl::ProcessKeyDown(NSEvent *_event)
{
    assert(m_Output);
    assert(_event);

    NSString *character = _event.charactersIgnoringModifiers;
    if( character.length != 1 )
        return;

    const uint16_t unicode = [character characterAtIndex:0];
    const auto modflags = _event.modifierFlags;

    const char *seq_resp = nullptr;
    switch( unicode ) {
        case NSUpArrowFunctionKey:
            seq_resp = m_ApplicationCursorKeys ? "\eOA" : "\e[A";
            break;
        case NSDownArrowFunctionKey:
            seq_resp = m_ApplicationCursorKeys ? "\eOB" : "\e[B";
            break;
        case NSRightArrowFunctionKey:
            seq_resp = m_ApplicationCursorKeys ? "\eOC" : "\e[C";
            break;
        case NSLeftArrowFunctionKey:
            seq_resp = m_ApplicationCursorKeys ? "\eOD" : "\e[D";
            break;
        case NSF1FunctionKey:
            seq_resp = "\eOP";
            break;
        case NSF2FunctionKey:
            seq_resp = "\eOQ";
            break;
        case NSF3FunctionKey:
            seq_resp = "\eOR";
            break;
        case NSF4FunctionKey:
            seq_resp = "\eOS";
            break;
        case NSF5FunctionKey:
            seq_resp = "\e[15~";
            break;
        case NSF6FunctionKey:
            seq_resp = "\e[17~";
            break;
        case NSF7FunctionKey:
            seq_resp = "\e[18~";
            break;
        case NSF8FunctionKey:
            seq_resp = "\e[19~";
            break;
        case NSF9FunctionKey:
            seq_resp = "\e[20~";
            break;
        case NSF10FunctionKey:
            seq_resp = "\e[21~";
            break;
        case NSF11FunctionKey:
            seq_resp = "\e[23~";
            break;
        case NSF12FunctionKey:
            seq_resp = "\e[24~";
            break;
        case NSHomeFunctionKey:
            seq_resp = "\eOH";
            break;
        case NSInsertFunctionKey:
            seq_resp = "\e[2~";
            break;
        case NSDeleteFunctionKey:
            seq_resp = "\e[3~";
            break;
        case NSEndFunctionKey:
            seq_resp = "\eOF";
            break;
        case NSPageUpFunctionKey:
            seq_resp = "\e[5~";
            break;
        case NSPageDownFunctionKey:
            seq_resp = "\e[6~";
            break;
        case 9:                                       /* tab */
            if( modflags & NSEventModifierFlagShift ) /* do we really getting these messages? */
                seq_resp = "\e[Z";
            else
                seq_resp = "\011";
            break;
        default:
            /* do nothing */;
    }

    if( seq_resp ) {
        m_Output(Bytes(reinterpret_cast<const std::byte *>(seq_resp), std::strlen(seq_resp)));
        return;
    }

    // process regular keys down
    if( modflags & NSEventModifierFlagControl ) {
        unsigned short cc = 0xFFFF;
        if( unicode >= 'a' && unicode <= 'z' )
            cc = unicode - 'a' + 1;
        else if( unicode == ' ' || unicode == '2' || unicode == '@' )
            cc = 0;
        else if( unicode == '[' )
            cc = 27;
        else if( unicode == '\\' )
            cc = 28;
        else if( unicode == ']' )
            cc = 29;
        else if( unicode == '^' || unicode == '6' )
            cc = 30;
        else if( unicode == '-' || unicode == '_' )
            cc = 31;
        m_Output(Bytes(reinterpret_cast<std::byte *>(&cc), 1));
        return;
    }

    if( modflags & NSEventModifierFlagOption )
        character =
            static_cast<NSString *>(CFBridgingRelease(CreateModifiedCharactersForKeyPress(_event.keyCode, modflags)));
    else if( (modflags & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCapsLock )
        character = _event.characters;

    const char *utf8 = character.UTF8String;
    m_Output(Bytes(reinterpret_cast<const std::byte *>(utf8), strlen(utf8)));
}

void InputTranslatorImpl::ProcessTextInput(NSString *_str)
{
    if( !_str || _str.length == 0 )
        return;

    const char *utf8str = [_str UTF8String];
    const size_t sz = strlen(utf8str);

    m_Output(Bytes(reinterpret_cast<const std::byte *>(utf8str), sz));
}

void InputTranslatorImpl::SetApplicationCursorKeys(bool _enabled)
{
    m_ApplicationCursorKeys = _enabled;
}

/**
 * That's a hacky implementation, it mimicks the real deadKeyState.
 * This can serve for purposes of decoding a single option-modified keypress, but can't be used for
 * double keys decoding
 */
static CFStringRef CreateModifiedCharactersForKeyPress(unsigned short _keycode, NSEventModifierFlags _flags)
{
    // http://stackoverflow.com/questions/12547007/convert-key-code-into-key-equivalent-string
    // http://stackoverflow.com/questions/8263618/convert-virtual-key-code-to-unicode-string
    // http://stackoverflow.com/questions/22566665/how-to-capture-unicode-from-key-events-without-an-nstextview

    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData =
        static_cast<CFDataRef>(TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData));
    const UCKeyboardLayout *keyboardLayout = reinterpret_cast<const UCKeyboardLayout *>(CFDataGetBytePtr(layoutData));
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

static std::string ReportX10(InputTranslator::MouseEvent _event) noexcept
{
    char buf[6];
    buf[0] = '\x1B';
    buf[1] = '[';
    buf[2] = 'M';
    switch( _event.type ) {
        case InputTranslator::MouseEvent::LDown:
            buf[3] = 32;
            break;
        case InputTranslator::MouseEvent::MDown:
            buf[3] = 33;
            break;
        case InputTranslator::MouseEvent::RDown:
            buf[3] = 34;
            break;
        case InputTranslator::MouseEvent::LUp:
        case InputTranslator::MouseEvent::MUp:
        case InputTranslator::MouseEvent::RUp:
            buf[3] = 35;
            break;
        default:
            return {};
    }
    buf[4] = static_cast<char>(std::clamp(_event.x + 32 + 1, 33, 255));
    buf[5] = static_cast<char>(std::clamp(_event.y + 32 + 1, 33, 255));
    return {buf, sizeof(buf)};
}

static std::string ReportNormal(InputTranslator::MouseEvent _event) noexcept
{
    constexpr int base = 32;
    char buf[6];
    buf[0] = '\x1B';
    buf[1] = '[';
    buf[2] = 'M';
    switch( _event.type ) {
        case InputTranslator::MouseEvent::LDown:
            buf[3] = base + 0;
            break;
        case InputTranslator::MouseEvent::MDown:
            buf[3] = base + 1;
            break;
        case InputTranslator::MouseEvent::RDown:
            buf[3] = base + 2;
            break;
        case InputTranslator::MouseEvent::LUp:
        case InputTranslator::MouseEvent::MUp:
        case InputTranslator::MouseEvent::RUp:
            buf[3] = base + 3;
            break;
        case InputTranslator::MouseEvent::LDrag:
            buf[3] = base + 0 + 32;
            break;
        case InputTranslator::MouseEvent::MDrag:
            buf[3] = base + 1 + 32;
            break;
        case InputTranslator::MouseEvent::RDrag:
            buf[3] = base + 2 + 32;
            break;
        case InputTranslator::MouseEvent::Motion:
            buf[3] = base + 3 + 32;
            break;
    }
    if( _event.shift )
        buf[3] |= 4;
    if( _event.alt )
        buf[3] |= 8;
    if( _event.control )
        buf[3] |= 16;
    buf[4] = static_cast<char>(std::clamp(_event.x + 32 + 1, 33, 255));
    buf[5] = static_cast<char>(std::clamp(_event.y + 32 + 1, 33, 255));
    return {buf, sizeof(buf)};
}

static std::string ReportUTF8(InputTranslator::MouseEvent _event) noexcept
{
    auto to_utf8 = [](unsigned int codepoint) -> std::string {
        std::string out;
        if( codepoint <= 0x7f )
            out.append(1, static_cast<char>(codepoint));
        else if( codepoint <= 0x7ff ) {
            out.append(1, static_cast<char>(0xc0 | ((codepoint >> 6) & 0x1f)));
            out.append(1, static_cast<char>(0x80 | (codepoint & 0x3f)));
        }
        return out;
    };

    constexpr int base = 32;
    std::string buf;
    buf += "\x1B[M";
    unsigned cb = 0;
    switch( _event.type ) {
        case InputTranslator::MouseEvent::LDown:
            cb = base + 0;
            break;
        case InputTranslator::MouseEvent::MDown:
            cb = base + 1;
            break;
        case InputTranslator::MouseEvent::RDown:
            cb = base + 2;
            break;
        case InputTranslator::MouseEvent::LUp:
        case InputTranslator::MouseEvent::MUp:
        case InputTranslator::MouseEvent::RUp:
            cb = base + 3;
            break;
        case InputTranslator::MouseEvent::LDrag:
            cb = base + 0 + 32;
            break;
        case InputTranslator::MouseEvent::MDrag:
            cb = base + 1 + 32;
            break;
        case InputTranslator::MouseEvent::RDrag:
            cb = base + 2 + 32;
            break;
        case InputTranslator::MouseEvent::Motion:
            cb = base + 3 + 32;
            break;
    }
    if( _event.shift )
        cb |= 4;
    if( _event.alt )
        cb |= 8;
    if( _event.control )
        cb |= 16;
    const unsigned x = std::clamp(_event.x + 32 + 1, 33, 2047);
    const unsigned y = std::clamp(_event.y + 32 + 1, 33, 2047);
    buf += to_utf8(cb);
    buf += to_utf8(x);
    buf += to_utf8(y);
    return buf;
}

static std::string ReportSGR(InputTranslator::MouseEvent _event) noexcept
{
    std::string buf;
    buf += "\x1B[<";
    unsigned cb = 0;
    switch( _event.type ) {
        case InputTranslator::MouseEvent::LDown:
        case InputTranslator::MouseEvent::LUp:
            cb = 0;
            break;
        case InputTranslator::MouseEvent::MDown:
        case InputTranslator::MouseEvent::MUp:
            cb = 1;
            break;
        case InputTranslator::MouseEvent::RDown:
        case InputTranslator::MouseEvent::RUp:
            cb = 2;
            break;
        case InputTranslator::MouseEvent::LDrag:
            cb = 0 + 32;
            break;
        case InputTranslator::MouseEvent::MDrag:
            cb = 1 + 32;
            break;
        case InputTranslator::MouseEvent::RDrag:
            cb = 2 + 32;
            break;
        case InputTranslator::MouseEvent::Motion:
            cb = 3 + 32;
            break;
    }
    if( _event.shift )
        cb |= 4;
    if( _event.alt )
        cb |= 8;
    if( _event.control )
        cb |= 16;
    const unsigned x = std::max(_event.x + 1, 1);
    const unsigned y = std::max(_event.y + 1, 1);
    buf += std::to_string(cb);
    buf += ";";
    buf += std::to_string(x);
    buf += ";";
    buf += std::to_string(y);
    switch( _event.type ) {
        case InputTranslator::MouseEvent::LUp:
        case InputTranslator::MouseEvent::MUp:
        case InputTranslator::MouseEvent::RUp:
            buf += "m";
            break;
        default:
            buf += "M";
            break;
    }
    return buf;
}

void InputTranslatorImpl::ProcessMouseEvent(MouseEvent _event)
{
    assert(m_Output);
    assert(m_MouseReportFormatter);
    const std::string result = m_MouseReportFormatter(_event);
    m_Output({reinterpret_cast<const std::byte *>(result.c_str()), result.length()});
}

void InputTranslatorImpl::SetMouseReportingMode(MouseReportingMode _mode)
{
    m_ReportingMode = _mode;
    switch( m_ReportingMode ) {
        case MouseReportingMode::X10:
            m_MouseReportFormatter = ReportX10;
            break;
        case MouseReportingMode::Normal:
            m_MouseReportFormatter = ReportNormal;
            break;
        case MouseReportingMode::UTF8:
            m_MouseReportFormatter = ReportUTF8;
            break;
        case MouseReportingMode::SGR:
            m_MouseReportFormatter = ReportSGR;
            break;
    }
}

void InputTranslatorImpl::ProcessPaste(std::string_view _utf8)
{
    if( _utf8.empty() )
        return;

    constexpr std::string_view bracket_prefix = "\x1B[200~";
    constexpr std::string_view bracket_postfix = "\x1B[201~";

    if( m_BracketedPaste ) {
        m_Output(Bytes(reinterpret_cast<const std::byte *>(bracket_prefix.data()), bracket_prefix.size()));
        m_Output(Bytes(reinterpret_cast<const std::byte *>(_utf8.data()), _utf8.size()));
        m_Output(Bytes(reinterpret_cast<const std::byte *>(bracket_postfix.data()), bracket_postfix.size()));
    }
    else {
        m_Output(Bytes(reinterpret_cast<const std::byte *>(_utf8.data()), _utf8.size()));
    }
}

void InputTranslatorImpl::SetBracketedPaste(bool _bracketed)
{
    m_BracketedPaste = _bracketed;
}

} // namespace nc::term
