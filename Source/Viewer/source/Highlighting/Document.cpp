// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/Document.h>
#include <stdlib.h>
#include <algorithm>
#include <iostream>

namespace nc::viewer::hl {

Document::Document(std::string_view _text) : m_Text(_text), m_Styles(_text.length())
{
}

Document::~Document() = default;

int Document::Version() const noexcept
{
    return Scintilla::dvRelease4;
}

int Document::CodePage() const
{
    return 65001; // UTF8
}

bool Document::IsDBCSLeadByte(char) const
{
    return false;
}

char Document::StyleAt(Sci_Position _position) const
{
    if( _position < 0 || _position >= static_cast<long>(m_Text.length()) ) {
        return 0;
    }
    return m_Styles[_position];
}

int Document::GetLevel(Sci_Position /*_line*/) const
{
    abort();
    return 0;
}

int Document::SetLevel(Sci_Position /*_line*/, int /*_level*/)
{
    abort();
    return 0;
}

int Document::GetLineState(Sci_Position /*_line*/) const
{
    abort();
    return 0;
}

int Document::SetLineState(Sci_Position /*_line*/, int /*_state*/)
{
    abort();
    return 0;
}

int Document::GetLineIndentation(Sci_Position /*_line*/)
{
    abort();
    return 0;
}

Sci_Position Document::LineEnd(Sci_Position _line) const
{

    if( _line < 0 ) {
        return 0;
    }

    unsigned long p = 0;
    for( ; p < m_Text.length(); ++p ) {
        if( m_Text[p] == '\n' ) {
            if( _line == 0 )
                return p;
            --_line;
        }
    }
    return p;
}

Sci_Position Document::GetRelativePosition(Sci_Position _position, Sci_Position _offset) const
{
    return _position + _offset;
}

int Document::GetCharacterAndWidth(Sci_Position _position, Sci_Position *_width) const
{
    // TODO: correct UTF-8 support
    if( _width ) {
        *_width = 1;
    }

    if( (_position < 0) || (_position >= Length()) ) {
        return '\0'; // Return NULs before document start and after document end
    }

    return m_Text.at(_position);
}

void Document::SetErrorStatus(int /*_status*/) noexcept
{
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
    // TODO: support CRLF
    return std::count(m_Text.begin(), m_Text.begin() + _pos, '\n');
}

Sci_Position Document::LineStart(Sci_Position _line) const noexcept
{
    if( _line < 0 ) {
        return 0;
    }

    unsigned long p = 0;
    for( ; p < m_Text.length() && _line > 0; ++p ) {
        if( m_Text[p] == '\n' )
            --_line;
    }
    return p;
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
}

void Document::DecorationFillRange(Sci_Position /*_position*/, int /*_value*/, Sci_Position /*_length*/) noexcept
{
}

void Document::ChangeLexerState(Sci_Position /*_start*/, Sci_Position /*_end*/) noexcept
{
}

} // namespace nc::viewer::hl
