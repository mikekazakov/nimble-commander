#include "HexModeFrame.h"
#include "HexModeProcessing.h"
#include <Habanero/algo.h>

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

HexModeFrame::RowsBuilder::RowsBuilder(const Source& _source,
                                       const std::byte *_raw_bytes_begin,
                                       const std::byte *_raw_bytes_end,
                                       int _digits_in_address):
    m_Source{_source},
    m_RawBytesBegin{_raw_bytes_begin},
    m_RawBytesEnd{_raw_bytes_end},
    m_DigitsInAddress{_digits_in_address},
    m_RawBytesNumber{ int(_raw_bytes_end - _raw_bytes_begin) }
{        
}
    
static base::CFPtr<CFStringRef> MakeSubstring(const CFStringRef _string,
                                              const std::pair<int, int> _range)
{
    assert( _range.first >= 0 && _range.second >= 0 );
    assert( _range.first + _range.second <= CFStringGetLength(_string) );
    const auto range = CFRangeMake(_range.first, _range.second);
    return base::CFPtr<CFStringRef>::adopt( CFStringCreateWithSubstring(nullptr,
                                                                        _string,
                                                                        range) );
}

HexModeFrame::Row HexModeFrame::RowsBuilder::Build(std::pair<int, int> const _chars_indices,
                                                   std::pair<int, int> const _string_bytes,
                                                   std::pair<int, int> const _row_bytes) const
{
    if( _row_bytes.first < 0 ||
        _row_bytes.second < 0 ||
        _row_bytes.first + _row_bytes.second > m_RawBytesNumber )
        throw std::out_of_range("HexModeFrame::RowsBuilder::Build invalid _row_bytes");

    std::vector<base::CFPtr<CFStringRef>> strings;
    
    // AddressIndex = 0
    auto address_str = HexModeSplitter::
    MakeAddressString(_row_bytes.first,
                      m_Source.working_set->GlobalOffset(),
                      m_Source.bytes_per_column * m_Source.number_of_columns,
                      m_DigitsInAddress);
    strings.emplace_back( std::move(address_str) );
    
    // SnippetIndex = 1
    strings.emplace_back( MakeSubstring(m_Source.working_set->String(), _chars_indices) );

    // ColumnsBaseIndex = 2
    auto bytes_ptr = m_RawBytesBegin + _row_bytes.first;
    const auto bytes_end = bytes_ptr + _row_bytes.second;
    const auto bytes_per_column = m_Source.bytes_per_column;
    for(int column = 0;
        column < m_Source.number_of_columns && bytes_ptr < bytes_end;
        ++column ) {
        const auto to_consume = std::min( bytes_per_column, int(bytes_end - bytes_ptr) );
        strings.emplace_back( HexModeSplitter::
                             MakeBytesHexString(bytes_ptr, bytes_ptr + to_consume) );
        bytes_ptr += to_consume;
    }
    
    // build CTLine objects
    std::vector<base::CFPtr<CTLineRef>> lines;
    for( const auto &string: strings ) {
        const auto attr_string = ToAttributeString(string.get());
        const auto line = CTLineCreateWithAttributedString(attr_string.get());
        lines.emplace_back( base::CFPtr<CTLineRef>::adopt(line) );
    }
    
    return Row(_chars_indices,
               _string_bytes,
               _row_bytes,
               std::move(strings),
               std::move(lines));
}

base::CFPtr<CFAttributedStringRef>
    HexModeFrame::RowsBuilder::ToAttributeString(CFStringRef _string) const
{
    // TODO: rewrite using CFAttributedStringCreate
    auto attr_string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    
    const auto full_range = CFRangeMake(0, CFStringGetLength(_string));
    CFAttributedStringReplaceString(attr_string,
                                    CFRangeMake(0, 0),
                                    _string);
    CFAttributedStringSetAttribute(attr_string,
                                   full_range,
                                   kCTForegroundColorAttributeName,
                                   m_Source.foreground_color);
    CFAttributedStringSetAttribute(attr_string,
                                   full_range,
                                   kCTFontAttributeName,
                                   m_Source.font);
    
    return base::CFPtr<CFAttributedStringRef>::adopt( (CFAttributedStringRef)attr_string );
}

}
