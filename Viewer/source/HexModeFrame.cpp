#include "HexModeFrame.h"
#include "HexModeProcessing.h"

namespace nc::viewer {
    
//    struct Line {
//    };
    
HexModeFrame::HexModeFrame( const Source &_source )
{
    if( _source.bytes_per_column < 1 )
        throw std::invalid_argument("_source.bytes_per_column can't be less than 1");
    if( _source.number_of_columns < 1 )
        throw std::invalid_argument("_source.number_of_columns can't be less than 1");
    if( _source.working_set == nullptr )
        throw std::invalid_argument("_source.working_set can't be nullptr");
    m_BytesPerColumn = _source.bytes_per_column;
    m_NumberOfColumns = _source.number_of_columns;
    m_WorkingSet = _source.working_set;
    
    HexModeSplitter::Source splitter_source;
    splitter_source.working_set = _source.working_set.get();
    splitter_source.bytes_per_row = m_BytesPerColumn * m_NumberOfColumns;
    const auto rows = HexModeSplitter::Split(splitter_source);
    
    
    
    
}
    
HexModeFrame::~HexModeFrame() = default;
    
    
HexModeFrame::Row::Row(std::pair<int, int> _chars_indices,  // start index, number of characters
                       std::pair<int, int> _string_bytes,   // start index, number of bytes
                       std::pair<int, int> _row_bytes,      // start index, number of bytes
                       std::vector<base::CFPtr<CFStringRef>> &&_strings,
                       std::vector<base::CFPtr<CTLineRef>> &&_lines)
{
    if( _strings.size() < 3 )
        throw std::invalid_argument("HexModeFrame::Row: _strings.size() can't be less than 3");
    if( _lines.size() < 3 )
        throw std::invalid_argument("HexModeFrame::Row: _lines.size() can't be less than 3");
    
    m_CharsStart = _chars_indices.first;
    m_CharsNum = _chars_indices.second;
    m_StringBytesStart = _string_bytes.first;
    m_StringBytesNum = _string_bytes.second;
    m_RowBytesStart = _row_bytes.first;
    m_RowBytesNum = _row_bytes.second;
    m_Strings = std::move(_strings);
    m_Lines = std::move(_lines);
}
    
HexModeFrame::Row::Row(Row&&) noexcept = default;
    
HexModeFrame::Row::~Row() = default;

HexModeFrame::Row& HexModeFrame::Row::operator=(Row&&) noexcept = default;

    

}
