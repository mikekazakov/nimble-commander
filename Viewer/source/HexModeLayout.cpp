#include "HexModeLayout.h"
#include <Habanero/CFRange.h>
#include <cmath>

namespace nc::viewer {
    
HexModeLayout::HexModeLayout(const Source &_source)
{
    m_Frame = _source.frame;
    m_ViewSize = _source.view_size;
    m_ScrollOffset = _source.scroll_offset;
    m_FileSize = _source.file_size;
}
    
HexModeLayout::ScrollerPosition HexModeLayout::CalcScrollerPosition() const noexcept
{
    const int bytes_in_view = BytesInView();
    if( m_FileSize > bytes_in_view ) {
        const auto &working_set = m_Frame->WorkingSet();
        ScrollerPosition position;
        position.position =
            double( working_set.GlobalOffset() + m_ScrollOffset.row * m_Frame->BytesPerRow() ) /
            double( m_FileSize - bytes_in_view );
        position.proportion =
            double( bytes_in_view ) /
            double(m_FileSize);
        return position;
    }
    else {
        ScrollerPosition position;
        position.position = 0.;
        position.proportion = 1.;
        return position;
    }
}
    
int HexModeLayout::RowsInView() const noexcept
{
    return (int)std::floor( m_ViewSize.height / m_Frame->FontInfo().LineHeight() );
}

int HexModeLayout::BytesInView() const noexcept
{
    const int rows_in_view = RowsInView();
    return rows_in_view * m_Frame->BytesPerRow();
}
    
void HexModeLayout::SetFrame( std::shared_ptr<const HexModeFrame> _new_frame )
{
    assert( _new_frame );
    m_Frame = std::move(_new_frame);
}

void HexModeLayout::SetViewSize( CGSize _new_view_size )
{
    m_ViewSize = _new_view_size;
}
    
void HexModeLayout::SetOffset(ScrollOffset _new_offset)
{
    m_ScrollOffset = _new_offset;
}

std::optional<int> HexModeLayout::
    FindRowToScrollWithGlobalOffset(int64_t _global_offset) const noexcept
{
    if( m_Frame->Empty() ) {
        return std::nullopt;
    }
    const auto rows_in_view = RowsInView();
    const auto working_set_pos = m_Frame->WorkingSet().GlobalOffset();
    const auto working_set_len = (int64_t)m_Frame->WorkingSet().BytesLength();
    const auto file_size = m_FileSize;
    const auto number_of_rows = m_Frame->NumberOfRows();

    if( _global_offset >= working_set_pos &&
       _global_offset < working_set_pos + working_set_len ) {
        // seems that we can satisfy this request immediately, without I/O
        const auto local_offset = (int)( _global_offset - working_set_pos );
        const auto first_row = &m_Frame->Rows()[0];
        const auto last_row = first_row + number_of_rows;
        const int closest = HexModeFrame::FindFloorClosest(first_row, last_row, local_offset);
        if( closest + rows_in_view < number_of_rows ) {
            // check that we will fill the whole screen after the scrolling
            return closest;
        }
        else if( working_set_pos + working_set_len == file_size ) {
            // special case if we're already at the bottom of the screen
            return std::clamp(number_of_rows - rows_in_view, 0, number_of_rows - 1);
        }
    }
    else if( _global_offset == file_size && working_set_pos + working_set_len == file_size ) {
        // special case if we're already at the bottom of the screen
        return std::clamp(number_of_rows - rows_in_view, 0, number_of_rows - 1);
    }
    return std::nullopt;
}
 
int64_t HexModeLayout::
    CalcGlobalOffsetForScrollerPosition( ScrollerPosition _scroller_position ) const noexcept
{
    const int64_t bytes_total = m_FileSize;
    const int64_t bytes_in_view = BytesInView();
    return (int64_t)( _scroller_position.position * double(bytes_total - bytes_in_view) );
}
    
int64_t HexModeLayout::CalcGlobalOffset() const noexcept
{
    const auto working_set_pos = m_Frame->WorkingSet().GlobalOffset();
    const auto first_row_index = m_ScrollOffset.row;
    if( first_row_index >= 0 && first_row_index < m_Frame->NumberOfRows() )
        return working_set_pos + (long)m_Frame->RowAtIndex(first_row_index).BytesStart();
    else
        return working_set_pos;
}
    
    
int HexModeLayout::FindEqualVerticalOffsetForRebuiltFrame
    (const HexModeFrame& old_frame,
     const int old_vertical_offset,
     const HexModeFrame& new_frame)
{
    if( &old_frame.WorkingSet() == &new_frame.WorkingSet() ) {
        if( old_vertical_offset < 0 ) {
            // offseting the old frame before the first row => offset remains the same
            return old_vertical_offset;
        }
        else if( old_vertical_offset >= old_frame.NumberOfRows() ) {
            // offseting the old frame after the last row => keep the delta the same
            const auto delta_offset = old_vertical_offset - old_frame.NumberOfRows();
            return new_frame.NumberOfRows() + delta_offset;
        }
        else {
            // some old line was an offset target - find the closest equivalent line in the
            // new frame.
            const auto &old_line = old_frame.RowAtIndex(old_vertical_offset);
            const auto old_byte_offset = old_line.BytesStart();
            const auto closest = HexModeFrame::FindClosest
            (new_frame.Rows().data(),
             new_frame.Rows().data() + new_frame.NumberOfRows(),
             old_byte_offset);
            return closest;
        }
    }
    else {
        const auto old_global_offset = old_frame.WorkingSet().GlobalOffset();
        const auto new_global_offset = new_frame.WorkingSet().GlobalOffset();
        
        if( old_vertical_offset < 0 ) {
            // this situation is rather weird, so let's just clamp the offset
            return 0;
        }
        else if( old_vertical_offset >= old_frame.NumberOfRows() ) {
            // offseting the old frame after the last row => find the equivalent row
            // and offset that one by the same rows delta
            const auto delta_offset = old_vertical_offset - old_frame.NumberOfRows();
            if( old_frame.NumberOfRows() == 0 )
                return delta_offset;
            const auto &last_old_line = old_frame.RowAtIndex( old_frame.NumberOfRows() - 1 );
            const auto old_byte_offset = last_old_line.BytesStart();
            const auto new_byte_offset= old_byte_offset + old_global_offset - new_global_offset;
            if( new_byte_offset < 0 || new_byte_offset > std::numeric_limits<int>::max() )
                return 0; // can't possibly satisfy
            const auto closest = HexModeFrame::FindClosest
            (new_frame.Rows().data(),
             new_frame.Rows().data() + new_frame.NumberOfRows(),
             (int)new_byte_offset);
            return closest + delta_offset;
        }
        else {
            // general case - get the line and find the closest in the new frame
            const auto &old_line = old_frame.RowAtIndex( old_vertical_offset );
            const auto old_byte_offset = old_line.BytesStart();
            const auto new_byte_offset = old_byte_offset + old_global_offset - new_global_offset;
            if( new_byte_offset < 0 || new_byte_offset > std::numeric_limits<int>::max() )
                return 0; // can't possibly satisfy
            const auto closest = HexModeFrame::FindClosest
            (new_frame.Rows().data(),
             new_frame.Rows().data() + new_frame.NumberOfRows(),
             (int)new_byte_offset);
            return closest;
        }
    }
}

void HexModeLayout::SetGaps( Gaps _gaps )
{
    m_Gaps = _gaps;
}    

HexModeLayout::HorizontalOffsets HexModeLayout::CalcHorizontalOffsets() const noexcept
{
    HorizontalOffsets offsets;
    offsets.address = m_Gaps.left_inset;
    
    const auto symb_width = m_Frame->FontInfo().PreciseMonospaceWidth();
    const auto address_width = m_Frame->DigitsInAddress() * symb_width;
    const auto column_width = m_Frame->BytesPerColumn() * (symb_width * 3) - symb_width; 
    const auto number_of_columns = m_Frame->NumberOfColumns();
    
    double x = offsets.address + address_width +  m_Gaps.address_columns_gap;
    offsets.columns.resize(number_of_columns);
    for( int i = 0; i < number_of_columns; ++i ) {        
        offsets.columns[i] = std::floor(x);
        x += column_width;
        if( i != number_of_columns - 1 )
            x += m_Gaps.between_columns_gap;
    }
    
    x += m_Gaps.columns_snippet_gap;
    offsets.snippet = std::floor(x);
    return offsets;
}
    
HexModeLayout::HitPart HexModeLayout::HitTest(double _x) const
{
    const auto offsets = CalcHorizontalOffsets();
    const auto gaps = m_Gaps;
    if( _x < offsets.columns.front() - gaps.address_columns_gap )
        return HitPart::Address;
    if( _x < offsets.columns.front() )
        return HitPart::AddressColumsGap;
    if( _x < offsets.snippet - gaps.columns_snippet_gap )
        return HitPart::Columns;
    if( _x < offsets.snippet )
        return HitPart::ColumnsSnippetGap;
    return HitPart::Snippet;
}

int HexModeLayout::RowIndexFromYCoordinate(const double _y) const
{
    const auto scrolled = _y + 
        m_ScrollOffset.row * m_Frame->FontInfo().LineHeight() + m_ScrollOffset.smooth;
    const auto index = (int)std::floor(scrolled / m_Frame->FontInfo().LineHeight());
    if( index < 0 )
        return -1;
    if( index >= m_Frame->NumberOfRows() )
        return m_Frame->NumberOfRows();
    return index;
}

int HexModeLayout::ByteOffsetFromColumnHit(CGPoint _position) const
{
    const auto row_index = RowIndexFromYCoordinate(_position.y);
    if( row_index < 0 )
        return 0;
    if( row_index >= m_Frame->NumberOfRows() )
        return m_Frame->WorkingSet().BytesLength();
    
    const auto x = _position.x;
    const auto &row = m_Frame->RowAtIndex(row_index);    
    const auto x_offsets = CalcHorizontalOffsets();
    if( x < x_offsets.columns.front() )
        return row.BytesStart();
    if( x >= x_offsets.snippet - m_Gaps.columns_snippet_gap )
        return row.BytesEnd();
    
    const auto symb_width = m_Frame->FontInfo().PreciseMonospaceWidth();
    const auto bytes_per_column = m_Frame->BytesPerColumn();
    const auto column_width = m_Frame->BytesPerColumn() * (symb_width * 3) - symb_width;
    
    for( int i = 0; i < row.ColumnsNumber(); ++i ) {
        if( i != row.ColumnsNumber() - 1 && x >= x_offsets.columns[i+1] )
            continue;
        
        if( x >= x_offsets.columns[i] + column_width ) {
            // hit into an inter-column-gap after the column
            return row.BytesStart() + std::min( bytes_per_column * (i+1), row.BytesNum() );
        }
        else {
            // hit into the column itself
            const auto local_x = x - x_offsets.columns[i];
            const auto triplet_fract = local_x / (symb_width * 3);
            const auto round_up = std::floor(triplet_fract) != std::floor(triplet_fract+0.33); 
            const auto local_byte = (int)std::floor(triplet_fract) + (round_up ? 1 : 0);
            return row.BytesStart() + std::min( bytes_per_column * i + local_byte, row.BytesNum() );
        }
    }
    return row.BytesEnd();    
}
    
int HexModeLayout::CharOffsetFromSnippetHit(CGPoint _position) const
{
    const auto row_index = RowIndexFromYCoordinate(_position.y);
    if( row_index < 0 )
        return 0;
    if( row_index >= m_Frame->NumberOfRows() )
        return m_Frame->WorkingSet().Length();
    
    const auto x = _position.x;
    const auto &row = m_Frame->RowAtIndex(row_index);    
    const auto x_offsets = CalcHorizontalOffsets();
    if( x <= x_offsets.snippet )
        return row.CharsStart();
    
     const auto ht = CTLineGetStringIndexForPosition(row.SnippetLine(),
                                                     CGPointMake(x - x_offsets.snippet, 0.) );
    if( ht == kCFNotFound )
        return row.CharsStart();
    return int(row.CharsStart() + ht);
}

std::pair<double, double> HexModeLayout::
    CalcColumnSelectionBackground(const CFRange _bytes_selection,
                                  const int _row_index,
                                  const int _columm_index,
                                  const HorizontalOffsets& _offsets) const
{
    const auto &row = m_Frame->RowAtIndex(_row_index);
    
    const auto bytes_range = CFRangeMake(row.BytesStart() + 
                                         _columm_index * m_Frame->BytesPerColumn(),
                                         row.BytesInColum(_columm_index)); 
    const auto sel_range = CFRangeIntersect(_bytes_selection, bytes_range);
    if( sel_range.length <= 0 )
        return {0., 0.};

    const auto local_start_byte = int(sel_range.location - 
                                      row.BytesStart() - 
                                      _columm_index * m_Frame->BytesPerColumn());  
    
    const auto symb_width = m_Frame->FontInfo().PreciseMonospaceWidth();    
    auto x1 = _offsets.columns.at(_columm_index) + local_start_byte * symb_width * 3;
    auto x2 = x1 + sel_range.length * symb_width * 3 - symb_width;
    return {std::floor(x1), std::ceil(x2)};
}
    
std::pair<double, double> HexModeLayout::
    CalcSnippetSelectionBackground(const CFRange _chars_selection,
                                   const int _row_index,
                                   const HorizontalOffsets& _offsets) const
{
    const auto &row = m_Frame->RowAtIndex(_row_index);
    const auto chars_range = CFRangeMake(row.CharsStart(), row.CharsNum());
    const auto sel_range = CFRangeIntersect(_chars_selection, chars_range);
    if( sel_range.length <= 0 ) // [      ]
        return {0., 0.};
    
    const auto ctline = row.SnippetLine();
    if( CFRangeInside(_chars_selection, chars_range) ) { // [******]
        const auto x1 = 0.;
        const auto x2 = CTLineGetOffsetForStringIndex(ctline, row.CharsNum(), nullptr);
        return { std::floor(x1) + _offsets.snippet, std::ceil(x2) + _offsets.snippet };
    }
    else if( sel_range.location == chars_range.location ) { // [****  ]
        const auto x1 = 0.;
        const auto x2 = CTLineGetOffsetForStringIndex(ctline,
                                                      CFRangeMax(sel_range) - row.CharsStart(),
                                                      nullptr);
        return { std::floor(x1) + _offsets.snippet, std::ceil(x2) + _offsets.snippet };
    }
    else { // [ ***  ]
        const auto x1 = CTLineGetOffsetForStringIndex(ctline,
                                                      sel_range.location - row.CharsStart(),
                                                      nullptr);
        const auto x2 = CTLineGetOffsetForStringIndex(ctline,
                                                      CFRangeMax(sel_range) - row.CharsStart(),
                                                      nullptr);
        return { std::floor(x1) + _offsets.snippet, std::ceil(x2) + _offsets.snippet };        
    }
}

std::pair<int, int> HexModeLayout::MergeSelection(const CFRange _existing_selection,
                                                  const bool _modifiying_existing,
                                                  const int _first_mouse_hit_index,
                                                  const int _current_mouse_hit_index) noexcept
{
    if( _modifiying_existing == false || 
       _existing_selection.location < 0 ||  
       _existing_selection.length <= 0 ) { 
        return {std::min(_first_mouse_hit_index, _current_mouse_hit_index),
                std::max(_first_mouse_hit_index, _current_mouse_hit_index)};
    }
    
    if( CFRangeInside(_existing_selection, _first_mouse_hit_index) ) {
        const auto attach_top = _first_mouse_hit_index - _existing_selection.location >
        _existing_selection.location + _existing_selection.length - _first_mouse_hit_index;
        const auto base = attach_top ?
        (int)_existing_selection.location :
        (int)_existing_selection.location + (int)_existing_selection.length;
        return {std::min(base, _current_mouse_hit_index), std::max(base, _current_mouse_hit_index)};
        
    }
    else if( _first_mouse_hit_index < CFRangeMax(_existing_selection) &&
            _current_mouse_hit_index < CFRangeMax(_existing_selection) ) {
        const auto base = (int)CFRangeMax(_existing_selection); 
        return {std::min(base, _current_mouse_hit_index), std::max(base, _current_mouse_hit_index)};
    }
    else if( _first_mouse_hit_index > _existing_selection.location &&
            _current_mouse_hit_index > _existing_selection.location ) {
        const auto base = (int)_existing_selection.location;
        return {std::min(base, _current_mouse_hit_index), std::max(base, _current_mouse_hit_index)};
    }
    else {
        return {std::min(_first_mouse_hit_index, _current_mouse_hit_index),
                std::max(_first_mouse_hit_index, _current_mouse_hit_index)};
    }
}

}
