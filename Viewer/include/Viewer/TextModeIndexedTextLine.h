#pragma once

#include <CoreText/CoreText.h>

namespace nc::viewer {
    
class TextModeIndexedTextLine
{
public:
    TextModeIndexedTextLine() noexcept;
    TextModeIndexedTextLine(int _unichars_start,
                    int _unichars_len,
                    int _bytes_start,
                    int _bytes_len,
                    CTLineRef _line // 'sinks' _line - no need to call CFRelease afterwards
                    );
    TextModeIndexedTextLine(const TextModeIndexedTextLine&) noexcept;
    TextModeIndexedTextLine(TextModeIndexedTextLine &&_r) noexcept;
    ~TextModeIndexedTextLine() noexcept;
    
    TextModeIndexedTextLine& operator=(const TextModeIndexedTextLine&) noexcept;
    TextModeIndexedTextLine& operator=(TextModeIndexedTextLine&&) noexcept;
    
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
    
/**
 * Returns the index of the line which has the closest start byte index to _bytes_offset.
 * The BytesStart() of that line can be either equal, less or greater than _bytes_offset.
 * the _bytes_offset value is meant to be local, i.e. comparable with the data in the lines,
 * not global.
 * Returns -1 if _first == _last.
 */
int FindClosestLineIndex(const TextModeIndexedTextLine *_first,
                         const TextModeIndexedTextLine *_last,
                         int _bytes_offset ) noexcept;

/**
 * Returns the index of the line which has the closest start byte index to _bytes_offset.
 * The BytesStart() of that line can be either equal or less than _bytes_offset.
 * the _bytes_offset value is meant to be local, i.e. comparable with the data in the lines,
 * not global.
 * Returns -1 if _first == _last.
 */
int FindFloorClosestLineIndex(const TextModeIndexedTextLine *_first,
                              const TextModeIndexedTextLine *_last,
                              int _bytes_offset ) noexcept;
    
inline int TextModeIndexedTextLine::UniCharsStart() const noexcept
{
    return m_UniCharsStart;
}
    
inline int TextModeIndexedTextLine::UniCharsLen() const noexcept
{
    return m_UniCharsLen;
}
    
inline int TextModeIndexedTextLine::UniCharsEnd() const noexcept
{
    return m_UniCharsStart + m_UniCharsLen;
}
    
inline int TextModeIndexedTextLine::BytesStart() const noexcept
{
    return m_BytesStart;
}

inline int TextModeIndexedTextLine::BytesLen() const noexcept
{
    return m_BytesLen;
}

inline int TextModeIndexedTextLine::BytesEnd() const noexcept
{
    return m_BytesStart + m_BytesLen;
}
    
inline CTLineRef TextModeIndexedTextLine::Line() const noexcept
{
    return m_Line;
}

inline bool TextModeIndexedTextLine::UniCharInside( int _unichar_index ) const noexcept
{
    return _unichar_index >= m_UniCharsStart &&
           _unichar_index < m_UniCharsStart + m_UniCharsLen;
}
    
inline bool TextModeIndexedTextLine::ByteInside( int _byte_index ) const noexcept
{
    return _byte_index >= m_BytesStart &&
           _byte_index < m_BytesStart + m_BytesLen;
}
    
}
