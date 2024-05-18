// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/Document.h>
#include <stdlib.h>
#include <algorithm>
#include <iostream>
#include <assert.h>

namespace nc::viewer::hl {

static constinit std::array<uint8_t, 256> g_UTF8Lengths = []() {
    std::array<uint8_t, 256> lengths = {};
    for( int i = 0; i < 0x80; ++i ) {
        lengths[i] = 1; // 0xxxxxxx (1 byte)
    }
    for( int i = 0x80; i < 0xC2; ++i ) {
        lengths[i] = 0; // Continuation bytes (invalid leading byte)
    }
    for( int i = 0xC2; i < 0xE0; ++i ) {
        lengths[i] = 2; // 110xxxxx (2 bytes)
    }
    for( int i = 0xE0; i < 0xF0; ++i ) {
        lengths[i] = 3; // 1110xxxx (3 bytes)
    }
    for( int i = 0xF0; i < 0xF5; ++i ) {
        lengths[i] = 4; // 11110xxx (4 bytes)
    }
    for( int i = 0xF5; i <= 0xFF; ++i ) {
        lengths[i] = 0; // Invalid leading byte
    }
    return lengths;
}();

static std::pair<int, int> UTF8Decode(std::string_view _str, Sci_Position _position) noexcept
{
    assert(_position >= 0);
    assert(static_cast<size_t>(_position) < _str.length());

    const uint8_t len = g_UTF8Lengths[static_cast<uint8_t>(_str[_position])];
    switch( len ) {
        case 0:
            return {'\0', 1};
        case 1:
            return {_str[_position], 1};
        case 2:
            if( static_cast<size_t>(_position + 1) < _str.length() ) {
                return {((static_cast<int>(_str[_position]) & 0x1F) << 6) +
                            (static_cast<int>(_str[_position + 1]) & 0x3F),
                        2};
            }
            else {
                return {'\0', 1};
            }
        case 3:
            if( static_cast<size_t>(_position + 2) < _str.length() ) {
                return {((static_cast<int>(_str[_position]) & 0xF) << 12) +
                            ((static_cast<int>(_str[_position + 1]) & 0x3F) << 6) +
                            (static_cast<int>(_str[_position + 2]) & 0x3F),
                        3};
            }
            else {
                return {'\0', 1};
            }
        default:
            if( static_cast<size_t>(_position + 3) < _str.length() ) {
                return {((static_cast<int>(_str[_position]) & 0x7) << 18) +
                            ((static_cast<int>(_str[_position + 1]) & 0x3F) << 12) +
                            ((static_cast<int>(_str[_position + 2]) & 0x3F) << 6) +
                            (static_cast<int>(_str[_position + 3]) & 0x3F),
                        4};
            }
            else {
                return {'\0', 1};
            }
    }
}

Document::Document(const std::string_view _text) : m_Text(_text), m_Styles(_text.length())
{
    // TODO: support CRLF
    m_Lines.push_back(0);
    for( size_t i = 0; i < _text.length(); ++i ) {
        if( _text[i] == '\n' ) {
            if( i < _text.length() - 1 )
                m_Lines.push_back(static_cast<uint32_t>(i + 1));
        }
    }
}

Document::~Document() = default;

int Document::Version() const noexcept
{
    return Scintilla::dvRelease4;
}

int Document::CodePage() const noexcept
{
    return 65001; // UTF8
}

bool Document::IsDBCSLeadByte(char) const noexcept
{
    return false;
}

char Document::StyleAt(Sci_Position _position) const noexcept
{
    if( _position < 0 || _position >= static_cast<long>(m_Text.length()) ) {
        return 0;
    }
    return m_Styles[_position];
}

int Document::GetLevel(Sci_Position /*_line*/) const noexcept
{
    abort();
    return 0;
}

int Document::SetLevel(Sci_Position /*_line*/, int /*_level*/) noexcept
{
    abort();
    return 0;
}

int Document::GetLineState(Sci_Position /*_line*/) const noexcept
{
    abort();
    return 0;
}

int Document::SetLineState(Sci_Position /*_line*/, int /*_state*/) noexcept
{
    abort();
    return 0;
}

int Document::GetLineIndentation(Sci_Position /*_line*/) noexcept
{
    abort();
    return 0;
}

Sci_Position Document::GetRelativePosition(Sci_Position _position, Sci_Position _offset) const noexcept
{
    return _position + _offset;
}

int Document::GetCharacterAndWidth(Sci_Position _position, Sci_Position *_width) const noexcept
{
    if( _position < 0 || static_cast<size_t>(_position) >= m_Text.size() ) {
        if( _width ) {
            *_width = 1;
        }
        return '\0'; // Return NULs before document start and after document end
    }

    const std::pair<int, int> code_len = UTF8Decode(m_Text, _position);
    if( _width )
        *_width = code_len.second;
    return code_len.first;
}

void Document::SetErrorStatus(int /*_status*/) noexcept
{
    abort();
}

Sci_Position Document::Length() const noexcept
{
    return m_Text.size();
}

void Document::GetCharRange(char *_buffer, Sci_Position _position, Sci_Position _length) const noexcept
{
    std::copy(m_Text.begin() + _position, m_Text.begin() + _position + _length, _buffer);
}

const char *Document::BufferPointer() noexcept
{
    return m_Text.data();
}

Sci_Position Document::LineFromPosition(Sci_Position _pos) const noexcept
{
    // O(nlogn)
    const auto it = std::lower_bound(m_Lines.begin(), m_Lines.end(), _pos);
    if( it == m_Lines.end() ) {
        return m_Lines.size() - 1;
    }
    return std::distance(m_Lines.begin(), it);
}

Sci_Position Document::LineStart(Sci_Position _line) const noexcept
{
    // O(1)
    if( _line < 0 ) {
        return 0;
    }
    if( static_cast<size_t>(_line) >= m_Lines.size() ) {
        return m_Text.length();
    }
    return m_Lines[_line];
}

Sci_Position Document::LineEnd(Sci_Position _line) const noexcept
{
    // O(1)
    if( _line < 0 ) {
        return 0;
    }
    if( static_cast<size_t>(_line + 1) >= m_Lines.size() ) {
        return m_Text.length();
    }
    return m_Lines[_line + 1] - 1; // NB! This will fail for CRLF!
}

void Document::StartStyling(Sci_Position _position) noexcept
{
    m_StylingPosition = _position;
}

bool Document::SetStyleFor(Sci_Position _length, char _style) noexcept
{
    for( int i = 0; i < _length; ++i ) {
        m_Styles[m_StylingPosition + i] = _style;
    }
    m_StylingPosition += _length;
    return true;
}

bool Document::SetStyles(Sci_Position _length, const char *_styles) noexcept
{
    for( int i = 0; i < _length; ++i ) {
        m_Styles[m_StylingPosition + i] = _styles[i];
    }
    m_StylingPosition += _length;
    return true;
}

void Document::DecorationSetCurrentIndicator(int /*_indicator*/) noexcept
{
    abort();
}

void Document::DecorationFillRange(Sci_Position /*_position*/, int /*_value*/, Sci_Position /*_length*/) noexcept
{
    abort();
}

void Document::ChangeLexerState(Sci_Position /*_start*/, Sci_Position /*_end*/) noexcept
{
    abort();
}

} // namespace nc::viewer::hl
