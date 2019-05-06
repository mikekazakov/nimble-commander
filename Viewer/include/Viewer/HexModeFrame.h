#pragma once

#include "TextModeWorkingSet.h"

#include <Utility/FontExtras.h>
#include <Habanero/CFPtr.h>
#include <Habanero/spinlock.h>

#include <memory>
#include <vector>

namespace nc::viewer {

class HexModeFrame
{
public:
    struct Source {
        std::shared_ptr<const TextModeWorkingSet> working_set;
        const std::byte *raw_bytes_begin;
        const std::byte *raw_bytes_end;
        int bytes_per_column = 8;
        int number_of_columns = 2;
        int digits_in_address = 10;
        CTFontRef font = nullptr;
        nc::utility::FontGeometryInfo font_info;
        CGColorRef foreground_color = nullptr;
    };
    
    class Row;
    class RowsBuilder;
    
    HexModeFrame( const Source &_source );
    HexModeFrame( const HexModeFrame& ) = delete;
    HexModeFrame( HexModeFrame&& ) = delete;
    ~HexModeFrame();
    HexModeFrame& operator=(const HexModeFrame&) = delete;
    HexModeFrame& operator=(HexModeFrame&&) = delete;
    
    int BytesPerRow() const noexcept;
    int BytesPerColumn() const noexcept;
    int NumberOfColumns() const noexcept;
    int DigitsInAddress() const noexcept;
    const TextModeWorkingSet& WorkingSet() const noexcept;
    const nc::utility::FontGeometryInfo &FontInfo() const noexcept;
    
    int NumberOfRows() const noexcept;
    bool Empty() const noexcept;
    
    const Row& RowAtIndex(int _row_index) const;
    const std::vector<Row> &Rows() const noexcept;
    
    /**
     * Returns the index of the row which has the closest start byte index to _bytes_offset.
     * The BytesStart() of that row can be either equal or less than _bytes_offset.
     * the _bytes_offset value is meant to be local, i.e. comparable with the data in the lines,
     * not global.
     * Returns -1 if _first == _last.
     */
    static int FindFloorClosest(const Row *_first, const Row *_last, int _bytes_offset ) noexcept;
    /** as FindFloorClosest, but the offset can be bigger too. */
    static int FindClosest(const Row *_first, const Row *_last, int _bytes_offset ) noexcept;
    
private:
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::vector<Row> m_Rows;
    nc::utility::FontGeometryInfo m_FontInfo;
    int m_BytesPerColumn;
    int m_NumberOfColumns;
    int m_DigitsInAddress;
};

class HexModeFrame::Row
{
public:
    Row() noexcept = default; // not to be used outside HexModeFrame
    Row( std::pair<int, int> _chars_indices, // start index, number of characters
         std::pair<int, int> _string_bytes,  // start index, number of bytes
         std::pair<int, int> _row_bytes,     // start index, number of bytes
         std::vector<base::CFPtr<CFStringRef>> &&_strings,
         std::vector<base::CFPtr<CTLineRef>> &&_lines,
         base::CFPtr<CFDictionaryRef> _attributes = {} );
    Row(const Row&) = delete;
    Row(Row&&) noexcept;
    ~Row();
    Row& operator=(const Row&) = delete;
    Row& operator=(Row&&) noexcept;
    
    CFStringRef AddressString() const noexcept;
    CFStringRef SnippetString() const noexcept;
    CFStringRef ColumnString(int _column) const;

    CTLineRef AddressLine() const noexcept;
    CTLineRef SnippetLine() const noexcept;
    CTLineRef ColumnLine(int _column) const;
    
    int ColumnsNumber() const noexcept;
    /* Returns amount of bytes represented by the specified column */
    int BytesInColum(int _column) const;
    
    /** Returns a bytes offset of this row inside a working set */
    int BytesStart() const noexcept;
    /** Returns a number of bytes covered by this row */
    int BytesNum() const noexcept;
    /** Returns a bytes offset of end of this row inside a working set */
    int BytesEnd() const noexcept;
    
    /** Returns a unicode chars start index inside a working set */
    int CharsStart() const noexcept;
    /** Returns a unicode chars end index inside a working set */
    int CharsEnd() const noexcept;
    /** Returns a numbers of unicode chars covered by this row */
    int CharsNum() const noexcept;
    
    enum {
        AddressIndex = 0,
        SnippetIndex = 1,
        ColumnsBaseIndex = 2
    };
    
private:
    /**
     * [0] is a row address
     * [1] is a string representation of this row (snippet)
     * [2...] are hexadecimal columns
     */
    std::vector<base::CFPtr<CFStringRef>> m_Strings;
    mutable std::vector<base::CFPtr<CTLineRef>> m_Lines;
    int m_CharsStart;       // unicode character index of the string start in the working set
    int m_CharsNum;         // amount of unicode characters in the line
    int m_StringBytesStart; // byte index of the string start in the working set
    int m_StringBytesNum;   // amount of bytes occupied by the string
    int m_RowBytesStart;    // byte index of the row start in the working set
    int m_RowBytesNum;      // amount of bytes occupied by the row
    base::CFPtr<CFDictionaryRef> m_Attributes;
};
    
class HexModeFrame::RowsBuilder
{
public:
    RowsBuilder(const Source& _source);
    
    Row Build(std::pair<int, int> _chars_indices,    // start index, number of characters
              std::pair<int, int> _string_bytes,     // start index, number of bytes
              std::pair<int, int> _row_bytes) const; // start index, number of bytes
    
private:
    const Source& m_Source;
    int const m_RawBytesNumber;
    base::CFPtr<CFDictionaryRef> m_Attributes;
};

inline int HexModeFrame::BytesPerRow() const noexcept
{
    return m_BytesPerColumn * m_NumberOfColumns;
}

inline int HexModeFrame::BytesPerColumn() const noexcept
{
    return m_BytesPerColumn;
}

inline int HexModeFrame::NumberOfColumns() const noexcept
{
    return m_NumberOfColumns;
}
    
inline int HexModeFrame::DigitsInAddress() const noexcept
{
    return m_DigitsInAddress;
}

inline const TextModeWorkingSet& HexModeFrame::WorkingSet() const noexcept
{
    return *m_WorkingSet;
}

inline int HexModeFrame::NumberOfRows() const noexcept
{
    return (int)m_Rows.size();
}
    
inline bool HexModeFrame::Empty() const noexcept
{
    return m_Rows.empty();
}

inline const HexModeFrame::Row& HexModeFrame::RowAtIndex(int _row_index) const
{
    return m_Rows.at(_row_index);
}

inline const std::vector<HexModeFrame::Row> &HexModeFrame::Rows() const noexcept
{
    return m_Rows;
}
    
inline const nc::utility::FontGeometryInfo &HexModeFrame::FontInfo() const noexcept
{
    return m_FontInfo;
}

inline CFStringRef HexModeFrame::Row::AddressString() const noexcept
{
    return m_Strings[AddressIndex].get();
}
    
inline CFStringRef HexModeFrame::Row::SnippetString() const noexcept
{
    return m_Strings[SnippetIndex].get();
}

inline CFStringRef HexModeFrame::Row::ColumnString(int _column) const
{
    return m_Strings.at(ColumnsBaseIndex + _column).get();
}

inline int HexModeFrame::Row::ColumnsNumber() const noexcept
{
    return (int)m_Strings.size() - ColumnsBaseIndex;
}
    
inline int HexModeFrame::Row::BytesStart() const noexcept
{
    return m_RowBytesStart;
}

inline int HexModeFrame::Row::BytesNum() const noexcept
{
    return m_RowBytesNum;
}
    
inline int HexModeFrame::Row::BytesEnd() const noexcept
{
    return m_RowBytesStart + m_RowBytesNum;
}
    
inline int HexModeFrame::Row::CharsStart() const noexcept
{
    return m_CharsStart;
}

inline int HexModeFrame::Row::CharsNum() const noexcept
{
    return m_CharsNum;
}
    
inline int HexModeFrame::Row::CharsEnd() const noexcept
{
    return m_CharsStart + m_CharsNum;
}

inline int HexModeFrame::Row::BytesInColum(int _column) const
{
    const auto chars_per_byte = 3;
    return int((CFStringGetLength(ColumnString(_column)) + 1)  / chars_per_byte); 
}

}
