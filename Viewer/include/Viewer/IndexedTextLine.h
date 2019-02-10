#pragma once

#include <CoreText/CoreText.h>

namespace nc::viewer {
    
class IndexedTextLine
{
public:
    IndexedTextLine() noexcept;
    IndexedTextLine(int _unichars_start,
                    int _unichars_len,
                    int _bytes_start,
                    int _bytes_len,
                    CTLineRef _line // 'sinks' _line - no need to call CFRelease afterwards
                    );
    IndexedTextLine(const IndexedTextLine&) noexcept;
    IndexedTextLine(IndexedTextLine &&_r) noexcept;
    ~IndexedTextLine() noexcept;
    
    IndexedTextLine& operator=(const IndexedTextLine&) noexcept;
    IndexedTextLine& operator=(IndexedTextLine&&) noexcept;
    
    int UniCharsStart() const noexcept;
    int UniCharsLen() const noexcept;
    int UniCharsEnd() const noexcept;
    int BytesStart() const noexcept;
    int BytesLen() const noexcept;
    int BytesEnd() const noexcept;
    CTLineRef Line() const noexcept;
    
    bool UniCharInside( int _unichar_index ) const noexcept;
    bool ByteInside( int _byte_index ) const noexcept;
    
private:
    /**
     * Index of a first unichar of this line whithin a string.
     */
    int m_UniCharsStart = 0;
    
    /**
     * Amount of unichars in this line.
     */
    int m_UniCharsLen = 0;
    
    /**
     * Offset within the part string of the current text line
     * (offset of a first unichar of this line).
     */
    int m_BytesStart = 0;
    
    /**
     * Amount of bytes in this line.
     */
    int m_BytesLen   = 0;
    
    /**
     * CoreText Line itself.
     */
    CTLineRef m_Line = nullptr;
};
    
inline int IndexedTextLine::UniCharsStart() const noexcept
{
    return m_UniCharsStart;
}
    
inline int IndexedTextLine::UniCharsLen() const noexcept
{
    return m_UniCharsLen;
}
    
inline int IndexedTextLine::UniCharsEnd() const noexcept
{
    return m_UniCharsStart + m_UniCharsLen;
}
    
inline int IndexedTextLine::BytesStart() const noexcept
{
    return m_BytesStart;
}

inline int IndexedTextLine::BytesLen() const noexcept
{
    return m_BytesLen;
}

inline int IndexedTextLine::BytesEnd() const noexcept
{
    return m_BytesStart + m_BytesLen;
}
    
inline CTLineRef IndexedTextLine::Line() const noexcept
{
    return m_Line;
}

inline bool IndexedTextLine::UniCharInside( int _unichar_index ) const noexcept
{
    return _unichar_index >= m_UniCharsStart &&
           _unichar_index < m_UniCharsStart + m_UniCharsLen;
}
    
inline bool IndexedTextLine::ByteInside( int _byte_index ) const noexcept
{
    return _byte_index >= m_BytesStart &&
           _byte_index < m_BytesStart + m_BytesLen;
}
    
}
