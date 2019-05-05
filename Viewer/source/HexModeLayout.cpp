#include "HexModeLayout.h"
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
 
int64_t HexModeLayout::CalcGlobalOffsetForScrollerPosition( ScrollerPosition _scroller_position ) const noexcept
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

    
}
