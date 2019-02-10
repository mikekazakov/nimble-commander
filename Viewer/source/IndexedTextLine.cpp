#include "IndexedTextLine.h"

namespace nc::viewer {
    

IndexedTextLine::IndexedTextLine() noexcept = default;
    
IndexedTextLine::IndexedTextLine(int _unichars_start,
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
    static_assert( sizeof(IndexedTextLine) == 24 );
}
    
IndexedTextLine::IndexedTextLine(const IndexedTextLine& _rhs) noexcept:
    m_UniCharsStart(_rhs.m_UniCharsStart),
    m_UniCharsLen(_rhs.m_UniCharsLen),
    m_BytesStart(_rhs.m_BytesStart),
    m_BytesLen(_rhs.m_BytesLen),
    m_Line(_rhs.m_Line)
{
    CFRetain(m_Line);
}
    
IndexedTextLine::IndexedTextLine(IndexedTextLine &&_rhs) noexcept:
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
    
IndexedTextLine::~IndexedTextLine() noexcept
{
    if( m_Line != nullptr )
        CFRelease(m_Line);
}
    
IndexedTextLine& IndexedTextLine::operator=(const IndexedTextLine& _rhs) noexcept
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
    
IndexedTextLine& IndexedTextLine::operator=(IndexedTextLine&& _rhs) noexcept
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

}
