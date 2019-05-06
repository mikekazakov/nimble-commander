#include "HexModeFrame.h"
#include "HexModeProcessing.h"
#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::viewer {

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
    m_FontInfo = _source.font_info;
    m_DigitsInAddress = _source.digits_in_address; 
    
    HexModeSplitter::Source splitter_source;
    splitter_source.working_set = _source.working_set.get();
    splitter_source.bytes_per_row = m_BytesPerColumn * m_NumberOfColumns;
    const auto rows = HexModeSplitter::Split(splitter_source);
    
    m_Rows.resize( rows.size() );
    RowsBuilder rows_builder(_source);
    auto block = [this, &rows, &rows_builder]( size_t _index ) {
        const auto &split = rows[_index];
        m_Rows[_index] = rows_builder.
        Build(std::make_pair(split.chars_start, split.chars_num),
              std::make_pair(split.string_bytes_start, split.string_bytes_num),
              std::make_pair(split.row_bytes_start, split.row_bytes_num));
    };
    dispatch_apply(rows.size(), dispatch_get_global_queue(0, 0), block);
}

HexModeFrame::~HexModeFrame() = default;

int HexModeFrame::
    FindFloorClosest(const Row *_first, const Row *_last, int _bytes_offset ) noexcept
{
    assert( _first != nullptr && _last != nullptr );
    assert( _last >= _first );
    
    if( _first == _last )
        return -1;
    
    const auto predicate = [](const Row &_lhs, int _rhs){
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
    
int HexModeFrame::FindClosest(const Row *_first, const Row *_last, int _bytes_offset ) noexcept
{
    assert( _first != nullptr && _last != nullptr );
    assert( _last >= _first );
    
    if( _first == _last )
        return -1;
    
    const auto predicate = [](const Row &_lhs, int _rhs){
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
    
HexModeFrame::Row::Row(std::pair<int, int> _chars_indices,  // start index, number of characters
                       std::pair<int, int> _string_bytes,   // start index, number of bytes
                       std::pair<int, int> _row_bytes,      // start index, number of bytes
                       std::vector<base::CFPtr<CFStringRef>> &&_strings,
                       std::vector<base::CFPtr<CTLineRef>> &&_lines,
                       base::CFPtr<CFDictionaryRef> _attributes)
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
    m_Attributes = std::move(_attributes);
}
    
HexModeFrame::Row::Row(Row&&) noexcept = default;
    
HexModeFrame::Row::~Row() = default;

HexModeFrame::Row& HexModeFrame::Row::operator=(Row&&) noexcept = default;

// This lazy computations below are not thread-safe atm, though I don't think that can be
// much of a problem:
// - it's very unlikely that any concurrent code would deal with CoreText stuff
// - in the worst case scenario there will be a leak of a CTLineRef object, which is
//   not an end of the world.
static base::CFPtr<CTLineRef> ToCTLine( CFStringRef _string, CFDictionaryRef _attributes )
{
    if( _string == nullptr || _attributes == nullptr )
        throw std::invalid_argument("ToCTLine: nullptr argument");
    const auto attr_string = base::CFPtr<CFAttributedStringRef>::adopt
        (CFAttributedStringCreate(nullptr, _string, _attributes) );
    return base::CFPtr<CTLineRef>::adopt( CTLineCreateWithAttributedString(attr_string.get()) );
}

CTLineRef HexModeFrame::Row::AddressLine() const noexcept
{
    auto &line = m_Lines[AddressIndex];
    if( !line )
        line = ToCTLine(m_Strings[AddressIndex].get(), m_Attributes.get());
    return line.get();
}
    
CTLineRef HexModeFrame::Row::SnippetLine() const noexcept
{
    auto &line = m_Lines[SnippetIndex];
    if( !line )
        line = ToCTLine(m_Strings[SnippetIndex].get(), m_Attributes.get());
    return line.get();
}
    
CTLineRef HexModeFrame::Row::ColumnLine(int _column) const
{
    auto &line = m_Lines.at(ColumnsBaseIndex + _column);
    if( !line )
        line = ToCTLine(m_Strings[ColumnsBaseIndex + _column].get(), m_Attributes.get());
    return line.get();
}
    
HexModeFrame::RowsBuilder::RowsBuilder(const Source& _source):
    m_Source{_source},
    m_RawBytesNumber{ int(_source.raw_bytes_end - _source.raw_bytes_begin) }
{
    const void *keys[2] = { kCTForegroundColorAttributeName, kCTFontAttributeName  };
    const void *values[2] = { m_Source.foreground_color, m_Source.font };
    const auto dict = CFDictionaryCreate(nullptr,
                                         keys,
                                         values,
                                         2,
                                         &kCFTypeDictionaryKeyCallBacks,
                                         &kCFTypeDictionaryValueCallBacks);
    m_Attributes = base::CFPtr<CFDictionaryRef>::adopt(dict);
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
                      m_Source.digits_in_address);
    strings.emplace_back( std::move(address_str) );
    
    // SnippetIndex = 1
    strings.emplace_back( MakeSubstring(m_Source.working_set->String(), _chars_indices) );

    // ColumnsBaseIndex = 2
    auto bytes_ptr = m_Source.raw_bytes_begin + _row_bytes.first;
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
    
    // make place for future CTLine objects
    std::vector<base::CFPtr<CTLineRef>> lines(strings.size());
    
    return Row(_chars_indices,
               _string_bytes,
               _row_bytes,
               std::move(strings),
               std::move(lines),
               m_Attributes);
}

}
