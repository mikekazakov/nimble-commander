#include "TextModeIndexedTextLine.h"
#include <algorithm>

namespace nc::viewer {
    

TextModeIndexedTextLine::TextModeIndexedTextLine() noexcept = default;
    
TextModeIndexedTextLine::TextModeIndexedTextLine(int _unichars_start,
                                 int _unichars_len,
                                 int _bytes_start,
                                 int _bytes_len,
                                 CTLineRef _line):
    m_UniCharsStart(_unichars_start),
    m_UniCharsLen(_unichars_len),
    m_BytesStart(_bytes_start),
    m_BytesLen(_bytes_len),
    m_Line(_line)
{
    // add some validation here?
    static_assert( sizeof(TextModeIndexedTextLine) == 24 );
}
    
TextModeIndexedTextLine::TextModeIndexedTextLine(const TextModeIndexedTextLine& _rhs) noexcept:
    m_UniCharsStart(_rhs.m_UniCharsStart),
    m_UniCharsLen(_rhs.m_UniCharsLen),
    m_BytesStart(_rhs.m_BytesStart),
    m_BytesLen(_rhs.m_BytesLen),
    m_Line(_rhs.m_Line)
{
    CFRetain(m_Line);
}
    
TextModeIndexedTextLine::TextModeIndexedTextLine(TextModeIndexedTextLine &&_rhs) noexcept:
    m_UniCharsStart(_rhs.m_UniCharsStart),
    m_UniCharsLen(_rhs.m_UniCharsLen),
    m_BytesStart(_rhs.m_BytesStart),
    m_BytesLen(_rhs.m_BytesLen),
    m_Line(_rhs.m_Line)
{
    _rhs.m_UniCharsStart = 0;
    _rhs.m_UniCharsLen = 0;
    _rhs.m_BytesStart = 0;
    _rhs.m_BytesLen = 0;
    _rhs.m_Line = nullptr;
}
    
TextModeIndexedTextLine::~TextModeIndexedTextLine() noexcept
{
    if( m_Line != nullptr )
        CFRelease(m_Line);
}
    
TextModeIndexedTextLine& TextModeIndexedTextLine::operator=(const TextModeIndexedTextLine& _rhs) noexcept
{
    if( this == &_rhs )
        return *this;
    if( m_Line != nullptr )
        CFRelease(m_Line);
    m_UniCharsStart = _rhs.m_UniCharsStart;
    m_UniCharsLen = _rhs.m_UniCharsLen;
    m_BytesStart = _rhs.m_BytesStart;
    m_BytesLen = _rhs.m_BytesLen;
    m_Line = _rhs.m_Line;
    CFRetain(m_Line);
    return *this;
}
    
TextModeIndexedTextLine& TextModeIndexedTextLine::operator=(TextModeIndexedTextLine&& _rhs) noexcept
{
    if( this == &_rhs )
        return *this;
    if( m_Line != nullptr )
        CFRelease(m_Line);
    m_UniCharsStart = _rhs.m_UniCharsStart;
    m_UniCharsLen = _rhs.m_UniCharsLen;
    m_BytesStart = _rhs.m_BytesStart;
    m_BytesLen = _rhs.m_BytesLen;
    m_Line = _rhs.m_Line;
    _rhs.m_UniCharsStart = 0;
    _rhs.m_UniCharsLen = 0;
    _rhs.m_BytesStart = 0;
    _rhs.m_BytesLen = 0;
    _rhs.m_Line = nullptr;
    return *this;
}

int FindClosestLineIndex(const TextModeIndexedTextLine *_first,
                         const TextModeIndexedTextLine *_last,
                         int _bytes_offset ) noexcept
{
    assert( _first != nullptr && _last != nullptr );
    assert( _last >= _first );
    
    if( _first == _last )
        return -1;
    
    const auto predicate = [](const TextModeIndexedTextLine &_lhs, int _rhs){
        return _lhs.BytesStart() < _rhs;
    };
    const auto lb = std::lower_bound( _first, _last, _bytes_offset, predicate );
    const auto index = (int)( lb - _first );
    if( lb == _first ) {
        // return the front index
        return 0;
    }
    else if( lb == _last ) {
        // return the last valid index
        return index - 1;
    }
    else {
        if( _first[index].BytesStart() == _bytes_offset ) {
            // if that's an exact hit - return immediately
            return index;
        }
        else {
            // or check distance with a previous line and choose which is closer
            auto delta_1 = _first[index].BytesStart() - _bytes_offset;
            auto delta_2 = _bytes_offset - _first[index - 1].BytesStart();
            if( delta_1 <= delta_2 )
                return index;
            else
                return index - 1;
        }
    }
}
    
int FindFloorClosestLineIndex(const TextModeIndexedTextLine *_first,
                              const TextModeIndexedTextLine *_last,
                              int _bytes_offset ) noexcept
{
    assert( _first != nullptr && _last != nullptr );
    assert( _last >= _first );
    
    if( _first == _last )
        return -1;
    
    const auto predicate = [](const TextModeIndexedTextLine &_lhs, int _rhs){
        return _lhs.BytesStart() < _rhs;
    };
    const auto lb = std::lower_bound( _first, _last, _bytes_offset, predicate );
    const auto index = (int)( lb - _first );
    if( lb == _first ) {
        // return the front index
        return 0;
    }
    else if( lb == _last ) {
        // return the last valid index
        return index - 1;
    }
    else {
        if( _first[index].BytesStart() == _bytes_offset ) {
            // if that's an exact hit - return immediately
            return index;
        }
        else {
            // or otherwise return the privous one
            return index - 1;
        }
    }        
}
    
}
