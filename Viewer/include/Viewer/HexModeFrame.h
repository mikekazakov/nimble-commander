#pragma once

#include "TextModeWorkingSet.h"

#include <Utility/FontExtras.h>
#include <Habanero/CFPtr.h>

#include <memory>
#include <vector>

namespace nc::viewer {


class HexModeFrame
{
public:
    struct Source {
        std::shared_ptr<const TextModeWorkingSet> working_set;
        int bytes_per_column = 8;
        int number_of_columns = 2;
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
    
    int BytesPerColumn() const noexcept;
    int NumberOfColumns() const noexcept;
    const TextModeWorkingSet& WorkingSet() const noexcept;
    
private:
    
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::vector<Row> m_Rows;
    int m_BytesPerColumn;
    int m_NumberOfColumns;
};

class HexModeFrame::Row
{
public:
    Row( std::pair<int, int> _chars_indices, // start index, number of characters
         std::pair<int, int> _string_bytes,  // start index, number of bytes
         std::pair<int, int> _row_bytes,     // start index, number of bytes
         std::vector<base::CFPtr<CFStringRef>> &&_strings,
         std::vector<base::CFPtr<CTLineRef>> &&_lines);
    Row(const Row&) = delete;
    Row(Row&&) noexcept;
    ~Row();
    Row& operator=(const Row&) = default;
    Row& operator=(Row&&) noexcept;
    
    CFStringRef AddressString() const noexcept;
    CFStringRef SnippetString() const noexcept;
    CFStringRef ColumnString(int _column) const;

    CTLineRef AddressLine() const noexcept;
    CTLineRef SnippetLine() const noexcept;
    CTLineRef ColumnLine(int _column) const;
    
    int ColumnsNumber() const noexcept;
    
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
    std::vector<base::CFPtr<CTLineRef>> m_Lines;
    int m_CharsStart;       // unicode character index of the string start in the working set
    int m_CharsNum;         // amount of unicode characters in the line
    int m_StringBytesStart; // byte index of the string start in the working set
    int m_StringBytesNum;   // amount of bytes occupied by the string
    int m_RowBytesStart;    // byte index of the row start in the working set
    int m_RowBytesNum;      // amount of bytes occupied by the row
};
    
class HexModeFrame::RowsBuilder
{
public:
    RowsBuilder(const Source& _source,
                const std::byte *_raw_bytes_begin,
                const std::byte *_raw_bytes_end,
                int _digits_in_address);
    
    Row Build(std::pair<int, int> _chars_indices,    // start index, number of characters
              std::pair<int, int> _string_bytes,     // start index, number of bytes
              std::pair<int, int> _row_bytes) const; // start index, number of bytes
    
private:
    base::CFPtr<CFAttributedStringRef> ToAttributeString(CFStringRef _string) const;
    const Source& m_Source;
    const std::byte * const m_RawBytesBegin;
    const std::byte * const m_RawBytesEnd;
    int const m_RawBytesNumber;
    int const m_DigitsInAddress;
};

inline int HexModeFrame::BytesPerColumn() const noexcept
{
    return m_BytesPerColumn;
}

inline int HexModeFrame::NumberOfColumns() const noexcept
{
    return m_NumberOfColumns;
}

inline const TextModeWorkingSet& HexModeFrame::WorkingSet() const noexcept
{
    return *m_WorkingSet;
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
    
inline CTLineRef HexModeFrame::Row::AddressLine() const noexcept
{
    return m_Lines[AddressIndex].get();
}
    
inline CTLineRef HexModeFrame::Row::SnippetLine() const noexcept
{
    return m_Lines[SnippetIndex].get();
}
    
inline CTLineRef HexModeFrame::Row::ColumnLine(int _column) const
{
    return m_Lines.at(ColumnsBaseIndex + _column).get();
}

inline int HexModeFrame::Row::ColumnsNumber() const noexcept
{
    return (int)m_Strings.size() - ColumnsBaseIndex;
}

}
