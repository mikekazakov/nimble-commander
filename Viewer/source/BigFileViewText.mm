// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BigFileViewText.h"
#include "BigFileView.h"
#include "TextProcessing.h"
#include "TextModeIndexedTextLine.h"
#include "TextModeWorkingSet.h"
#include <Habanero/algo.h>
#include <Utility/NSView+Sugar.h>

#include <cmath>

namespace nc::viewer {

static const auto g_TabSpaces = 4;
static const auto g_WrappingWidth = 10000.;

static std::shared_ptr<const TextModeWorkingSet> MakeEmptyWorkingSet()
{
    char16_t chars[1] = {' '};
    int offsets[1] = {0};
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = chars;
    source.mapping_to_byte_offsets = offsets;
    source.characters_number = 0;
    source.bytes_offset = 0;
    source.bytes_length = 0;
    return std::make_shared<TextModeWorkingSet>(source);
}

BigFileViewText::BigFileViewText(BigFileViewDataBackend* _data, BigFileView* _view):
    m_View(_view),
    m_Data(_data),
    m_FrameSize(CGSizeMake(0, 0)),
    m_SmoothScroll(_data->IsFullCoverage()),
    m_WorkingSet(MakeEmptyWorkingSet())
{
    GrabFontGeometry();
    OnFrameChanged();
    OnBufferDecoded();
    [m_View setNeedsDisplay];
}

BigFileViewText::~BigFileViewText()
{
}

void BigFileViewText::GrabFontGeometry()
{
    m_FontInfo = nc::utility::FontGeometryInfo( [m_View TextFont] );
}

void BigFileViewText::OnBufferDecoded()
{
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = (const char16_t*)m_Data->UniChars();
    source.mapping_to_byte_offsets = (const int*)m_Data->UniCharToByteIndeces();
    source.characters_number = m_Data->UniCharsSize();
    source.bytes_offset = (long)m_Data->FilePos();
    source.bytes_length = (int)m_Data->RawSize();
    m_WorkingSet = std::make_shared<TextModeWorkingSet>(source);
    
    BuildLayout();
}

void BigFileViewText::BuildLayout()
{
    const auto wrapping_width = m_View.wordWrap ?
        m_View.contentBounds.width - m_LeftInset :
        g_WrappingWidth;
 
    TextModeFrame::Source source;
    source.wrapping_width = wrapping_width;
    source.font = [m_View TextFont];
    source.font_info = m_FontInfo;
    source.foreground_color = [m_View TextForegroundColor];
    source.tab_spaces = g_TabSpaces;
    source.working_set = m_WorkingSet;
    m_Frame = std::make_shared<TextModeFrame>(source);
    
    if( m_VerticalOffset >= m_Frame->LinesNumber() )
        m_VerticalOffset = std::max( m_Frame->LinesNumber() - 1, 0 );
    
    [m_View setNeedsDisplay];
}

CGPoint BigFileViewText::TextAnchor()
{
    const double x = std::ceil(( m_LeftInset - m_HorizontalOffset * m_FontInfo.MonospaceWidth()) )
        - m_SmoothOffset.x;
    const double y = std::floor(m_View.contentBounds.height + m_SmoothOffset.y);
    return NSMakePoint(x, y);
}
    
CGPoint BigFileViewText::ToFrameCoords(CGPoint _view_coords)
{
    CGPoint left_upper = TextAnchor();
    return CGPointMake(_view_coords.x - left_upper.x,
                       left_upper.y - _view_coords.y + m_VerticalOffset * m_FontInfo.LineHeight());
}

void BigFileViewText::DoDraw(CGContextRef _context, NSRect _dirty_rect)
{
    CGContextSetFillColorWithColor(_context, m_View.BackgroundFillColor);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, true);
    CGContextSetShouldAntialias(_context, true);
    
    CGPoint pos = TextAnchor();
    pos.y = pos.y - m_FontInfo.LineHeight() + m_FontInfo.Descent();
    
    double view_width = m_View.contentBounds.width;
    
    int first_string = m_VerticalOffset;
    if( m_SmoothOffset.y < 0 && first_string > 0 ) {
        --first_string; // to be sure that we can see bottom-clipped lines
        pos.y += m_FontInfo.LineHeight();
    }
    
    CFRange selection = [m_View SelectionWithinWindowUnichars];
    
     for(int i = first_string;
         i < m_Frame->LinesNumber() && pos.y >= 0 - m_FontInfo.LineHeight();
         ++i, pos.y -= m_FontInfo.LineHeight())
     {
         auto &line = m_Frame->Line(i);
         
         if(selection.location >= 0) // draw a selection background here
         {
             CGFloat x1 = 0, x2 = -1;
             if(line.UniCharsStart() <= selection.location &&
                line.UniCharsEnd() > selection.location )
             {
                 x1 = pos.x + CTLineGetOffsetForStringIndex(line.Line(), selection.location, 0);
                 x2 = ((selection.location + selection.length <= line.UniCharsEnd()) ?
                       pos.x + CTLineGetOffsetForStringIndex(line.Line(),
                                                    (selection.location + selection.length <= line.UniCharsEnd()) ?
                                                    selection.location + selection.length : line.UniCharsEnd(),
                                               0) : view_width);
             }
             else if(selection.location + selection.length > line.UniCharsStart() &&
                     selection.location + selection.length <= line.UniCharsEnd() )
             {
                 x1 = pos.x;
                 x2 = pos.x + CTLineGetOffsetForStringIndex(line.Line(), selection.location + selection.length, 0);
             }
             else if(selection.location < line.UniCharsStart() &&
                     selection.location + selection.length > line.UniCharsEnd() )
             {
                 x1 = pos.x;
                 x2 = view_width;
             }

             if(x2 > x1)
             {
                 CGContextSaveGState(_context);
                 CGContextSetShouldAntialias(_context, false);
                 //m_View.SelectionBkFillColor.Set(_context);
                 CGContextSetFillColorWithColor(_context, m_View.SelectionBkFillColor);
                 CGContextFillRect(_context, CGRectMake(x1, pos.y - m_FontInfo.Descent(), x2 - x1, m_FontInfo.LineHeight()));
                 CGContextRestoreGState(_context);
             }
         }
         
         CGContextSetTextPosition( _context, pos.x, pos.y );
         CTLineDraw(line.Line(), _context);
     }
}

void BigFileViewText::CalculateScrollPosition( double &_position, double &_knob_proportion )
{
    _position = 0.0;
    _knob_proportion = 1.0;
    const auto lines_number = m_Frame->LinesNumber();
    if( !m_SmoothScroll ) {
        if( m_VerticalOffset < lines_number ) {
            uint64_t byte_pos = m_Frame->Line(m_VerticalOffset).BytesStart() + m_Data->FilePos();
            uint64_t last_visible_byte_pos =
                m_Frame->Line( std::min(m_VerticalOffset + m_FrameLines,
                                        lines_number - 1
                                        )
                              ).BytesStart() + m_Data->FilePos();
            uint64_t byte_scroll_size = m_Data->FileSize() - (last_visible_byte_pos - byte_pos);
            double prop = double(last_visible_byte_pos - byte_pos) / double(m_Data->FileSize());
            _position = double(byte_pos) / double(byte_scroll_size);
            _knob_proportion = prop;
        }
    }
    else
    {
        double pos = 0.;
        if( lines_number > m_FrameLines )
            pos = double(m_VerticalOffset) / double(lines_number - m_FrameLines);
        double prop = 1.;
        if( lines_number > m_FrameLines )
            prop = double(m_FrameLines) / double(lines_number);
        _position = pos;
        _knob_proportion = prop;
    }
}

void BigFileViewText::MoveLinesDelta(int _delta)
{
    if( m_Frame->Empty() )
        return;
    
    const int lines_number = m_Frame->LinesNumber();
    assert( m_VerticalOffset < lines_number );
    const uint64_t window_pos = m_Data->FilePos();
    const uint64_t window_size = m_Data->RawSize();
    const uint64_t file_size = m_Data->FileSize();
    
    if( _delta < 0 ) { // we're moving up
        // check if we can satisfy request within our current window position, without moving it
        if( m_VerticalOffset + _delta >= 0 ) {
            // ok, just scroll within current window
            m_VerticalOffset += _delta;
        }
        else {
            // nope, we need to move file window if it is possible
            if( window_pos > 0 ) { // ok, can move - there's a space
                uint64_t anchor_glob_offset =
                    m_Frame->Line(m_VerticalOffset).BytesStart() + window_pos;
                int anchor_pos_on_screen = -_delta;
                
                // TODO: need something more intelligent here
                uint64_t desired_window_offset = anchor_glob_offset > 3*window_size/4 ?
                                                    anchor_glob_offset - 3*window_size/4 :
                                                    0;
                MoveFileWindowTo(desired_window_offset, anchor_glob_offset, anchor_pos_on_screen);
            }
            else
            { // window is already at the top, need to move scroll within window
                m_SmoothOffset.y = 0;
                m_VerticalOffset = 0;
            }
        }
        [m_View setNeedsDisplay];
    }
    else if(_delta > 0) { // we're moving down
        if( m_VerticalOffset + _delta + m_FrameLines < lines_number ) {
            // ok, just scroll within current window
            m_VerticalOffset += _delta;
        }
        else {
            // nope, we need to move file window if it is possible
            if(window_pos + window_size < file_size)
            { // ok, can move - there's a space
                int anchor_index = std::min(m_VerticalOffset + _delta - 1,
                                               lines_number - 1);
                int anchor_pos_on_screen = -1;
                
                uint64_t anchor_glob_offset = m_Frame->Line(anchor_index).BytesStart() + window_pos;

                assert(anchor_glob_offset > window_size/4); // internal logic check
                // TODO: need something more intelligent here
                uint64_t desired_window_offset = anchor_glob_offset - window_size/4;
                desired_window_offset = std::clamp(desired_window_offset, 0ull, file_size - window_size);
                
                MoveFileWindowTo(desired_window_offset, anchor_glob_offset, anchor_pos_on_screen);
            }
            else
            { // just move offset to the end within our window
                if(m_VerticalOffset + m_FrameLines < lines_number)
                    m_VerticalOffset = lines_number - m_FrameLines;
            }
        }
        [m_View setNeedsDisplay];
    }
}

void BigFileViewText::OnUpArrow()
{
    MoveLinesDelta(-1);
}

void BigFileViewText::OnDownArrow()
{
    MoveLinesDelta(1);
}

void BigFileViewText::OnPageDown()
{
    MoveLinesDelta(m_FrameLines);
}

void BigFileViewText::OnPageUp()
{
    MoveLinesDelta(-m_FrameLines);
}

void BigFileViewText::MoveFileWindowTo(uint64_t _pos, uint64_t _anchor_byte_no, int _anchor_line_no)
{
    // now move our file window
    // data updating and layout stuff are called implicitly after that call
    [m_View RequestWindowMovementAt:_pos];
    
    // now we need to find a line which is at last_top_line_glob_offset position
    if( m_Frame->Empty() ) {
        m_VerticalOffset = 0;
        return;
    }
    
    const int local_offset = (int)( _anchor_byte_no - m_WorkingSet->GlobalOffset() );
    const auto first_line = &m_Frame->Lines()[0];
    const auto last_line = first_line + m_Frame->LinesNumber();
    const int closest_ind = FindFloorClosestLineIndex( first_line, last_line, local_offset );
    
    m_VerticalOffset = std::max(closest_ind - _anchor_line_no, 0);
    
    assert( m_VerticalOffset < m_Frame->LinesNumber() );
    [m_View setNeedsDisplay];
}

uint32_t BigFileViewText::GetOffsetWithinWindow()
{
    if( m_Frame->Empty() == false ) {
        assert( m_VerticalOffset < m_Frame->LinesNumber() );
        return m_Frame->Line(m_VerticalOffset).BytesStart();
    }
    else {
        assert( m_VerticalOffset == 0 );
        return 0;
    }
}

void BigFileViewText::MoveOffsetWithinWindow(uint32_t _offset)
{
    const auto first_line = &m_Frame->Lines()[0];
    const auto last_line = first_line + m_Frame->LinesNumber();
    const auto closest_index = FindClosestLineIndex(first_line, last_line, (int)_offset);
    m_VerticalOffset = std::max(closest_index, 0);
    assert( m_Frame->Empty() || m_VerticalOffset < m_Frame->LinesNumber() );
}

void BigFileViewText::ScrollToByteOffset(uint64_t _offset)
{
    const uint64_t window_pos = m_Data->FilePos();
    const uint64_t window_size = m_Data->RawSize();
    const uint64_t file_size = m_Data->FileSize();
    
    m_SmoothOffset.y = 0; // reset vertical smoothing on any scrolling-to-line
    
    if((_offset >= window_pos && _offset < window_pos + window_size) ||
       (_offset == file_size && window_pos + window_size == file_size) ) {
        // seems that we can satisfy this request immediately, without I/O
        const int local_offset = (int)( _offset - m_WorkingSet->GlobalOffset() );
        const auto first_line = &m_Frame->Lines()[0];
        const auto last_line = first_line + m_Frame->LinesNumber();
        const int closest = FindFloorClosestLineIndex(first_line, last_line, local_offset);
        if( closest + m_FrameLines < m_Frame->LinesNumber() )
        { // check that we will fill whole screen after scrolling
            m_VerticalOffset = closest;
            [m_View setNeedsDisplay];
            return;
        }
        else if(window_pos + window_size == file_size)
        { // trying to scroll below bottom
            m_VerticalOffset = std::clamp(m_Frame->LinesNumber() - m_FrameLines,
                                          0,
                                          m_Frame->LinesNumber() - 1);
            [m_View setNeedsDisplay];
            return;
        }
    }

    // nope, we need to perform I/O - to move file window
    uint64_t desired_wnd_pos = _offset > window_size / 2 ?
                                _offset - window_size / 2 :
                                0;
    desired_wnd_pos = std::clamp(desired_wnd_pos, 0ull, file_size - window_size);
    
    MoveFileWindowTo(desired_wnd_pos, _offset, 0);
    
    assert( m_Frame->Empty() || m_VerticalOffset < m_Frame->LinesNumber() );
}

void BigFileViewText::HandleVerticalScroll(double _pos)
{
    if(!m_SmoothScroll)
    { // scrolling by bytes offset
        uint64_t file_size = m_Data->FileSize();
        uint64_t bytepos = uint64_t( _pos * double(file_size) ); // need to substract current screen's size in bytes
        ScrollToByteOffset(bytepos);
        
        if( m_Frame->LinesNumber() - m_VerticalOffset < m_FrameLines )
            m_VerticalOffset = m_Frame->LinesNumber() - m_FrameLines;

        m_SmoothOffset.y = 0;
    }
    else
    { // we have all file decomposed into strings, so we can do smooth scrolling now
        double full_document_size = double(m_Frame->LinesNumber()) * m_FontInfo.LineHeight();
        double scroll_y_offset = _pos * (full_document_size - m_FrameSize.height);
        m_VerticalOffset = (int)std::floor(scroll_y_offset / m_FontInfo.LineHeight());
        m_SmoothOffset.y = scroll_y_offset - m_VerticalOffset * m_FontInfo.LineHeight();
        [m_View setNeedsDisplay];
    }
    assert( m_Frame->Empty() || m_VerticalOffset < m_Frame->LinesNumber() );
}

void BigFileViewText::OnScrollWheel(NSEvent *theEvent)
{
    double delta_y = theEvent.scrollingDeltaY;
    double delta_x = theEvent.scrollingDeltaX;
    if(!theEvent.hasPreciseScrollingDeltas)
    {
        delta_y *= m_FontInfo.LineHeight();
        delta_x *= m_FontInfo.MonospaceWidth();
    }
    
    // vertical scrolling
    if(!m_SmoothScroll)
    {
        if((delta_y > 0 && (m_Data->FilePos() > 0 ||
                            m_VerticalOffset > 0)       ) ||
           (delta_y < 0 && (m_Data->FilePos() + m_Data->RawSize() < m_Data->FileSize() ||
                            m_VerticalOffset + m_FrameLines < m_Frame->LinesNumber()) )
           )
        {
            m_SmoothOffset.y -= delta_y;
        
            while(m_SmoothOffset.y < -m_FontInfo.LineHeight()) {
                OnUpArrow();
                m_SmoothOffset.y += m_FontInfo.LineHeight();
            }
            while(m_SmoothOffset.y > m_FontInfo.LineHeight()) {
                OnDownArrow();
                m_SmoothOffset.y -= m_FontInfo.LineHeight();
            }
        }
        else
            return;
    }
    else
    {
        if((delta_y > 0 && m_VerticalOffset > 0) ||
           (delta_y < 0 && m_VerticalOffset + m_FrameLines < m_Frame->LinesNumber()) )
        {
            m_SmoothOffset.y -= delta_y;
            if(m_SmoothOffset.y < -m_FontInfo.LineHeight())
            {
                int dl = int(-m_SmoothOffset.y / m_FontInfo.LineHeight());
                if((int)m_VerticalOffset > dl) m_VerticalOffset -= dl;
                else m_VerticalOffset = 0;
                m_SmoothOffset.y += dl * m_FontInfo.LineHeight();
            }
            else if(m_SmoothOffset.y > m_FontInfo.LineHeight())
            {
                int dl = int(m_SmoothOffset.y / m_FontInfo.LineHeight());
                if( m_VerticalOffset + m_FrameLines + dl < m_Frame->LinesNumber() )
                    m_VerticalOffset += dl;
                else
                    m_VerticalOffset = m_Frame->LinesNumber() - m_FrameLines;
                m_SmoothOffset.y -= dl * m_FontInfo.LineHeight();
            }
        }
        else
            return;
    }
    
    // horizontal scrolling
    if( !m_View.wordWrap && ((delta_x > 0 && m_HorizontalOffset > 0) || delta_x < 0) )
    {
        m_SmoothOffset.x -= delta_x;
        if(m_SmoothOffset.x > m_FontInfo.MonospaceWidth())
        {
            int dx = int(m_SmoothOffset.x / m_FontInfo.MonospaceWidth());
            m_HorizontalOffset += dx;
            m_SmoothOffset.x -= dx * m_FontInfo.MonospaceWidth();
            
        }
        else if(m_SmoothOffset.x < -m_FontInfo.MonospaceWidth())
        {
            int dx = int(-m_SmoothOffset.x / m_FontInfo.MonospaceWidth());
            if((int)m_HorizontalOffset > dx) m_HorizontalOffset -= dx;
            else m_HorizontalOffset = 0;
            m_SmoothOffset.x += dx * m_FontInfo.MonospaceWidth();
        }
    }
    
    // edge-case clipping (not allowing to appear a gap before first line or after last line or before the first line's character)
    if(m_Data->FilePos() == 0 &&
       m_VerticalOffset == 0 &&
       m_SmoothOffset.y < 0)
        m_SmoothOffset.y = 0;
    if(m_Data->FilePos() + m_Data->RawSize() == m_Data->FileSize() &&
       m_VerticalOffset + m_FrameLines >= m_Frame->LinesNumber() &&
       m_SmoothOffset.y > 0 )
        m_SmoothOffset.y = 0;
    if(m_HorizontalOffset == 0 && m_SmoothOffset.x > 0)
        m_SmoothOffset.x = 0;
    
    [m_View setNeedsDisplay];
    assert( m_Frame->Empty() || m_VerticalOffset < m_Frame->LinesNumber() );
}

void BigFileViewText::OnFrameChanged()
{
    NSSize sz = m_View.contentBounds;
    m_FrameLines = int(sz.height / m_FontInfo.LineHeight());

    if(m_FrameSize.width != sz.width)
        BuildLayout();
    m_FrameSize = sz;
}

void BigFileViewText::OnWordWrappingChanged()
{
    BuildLayout();
    if( m_VerticalOffset >= m_Frame->LinesNumber() ) {
        if( m_Frame->LinesNumber() >= m_FrameLines )
            m_VerticalOffset = m_Frame->LinesNumber() - m_FrameLines;
        else
            m_VerticalOffset = 0;
    }
    m_HorizontalOffset = 0;
    m_SmoothOffset.x = 0;
}

void BigFileViewText::OnFontSettingsChanged()
{
    GrabFontGeometry();
    OnFrameChanged();
    BuildLayout();
}

void BigFileViewText::OnLeftArrow()
{
    if(m_View.wordWrap)
        return;
    
    m_HorizontalOffset -= m_HorizontalOffset > 0 ? 1 : 0;
    [m_View setNeedsDisplay];
}

void BigFileViewText::OnRightArrow()
{
    if(m_View.wordWrap)
        return;
    
    m_HorizontalOffset++;
    [m_View setNeedsDisplay];
}

void BigFileViewText::OnMouseDown(NSEvent *event)
{
    if(event.clickCount > 2)
        HandleSelectionWithTripleClick(event);
    else if (event.clickCount == 2)
        HandleSelectionWithDoubleClick(event);
    else
        HandleSelectionWithMouseDragging(event);
}

void BigFileViewText::HandleSelectionWithTripleClick(NSEvent* event)
{
    const auto view_coords = [m_View convertPoint:event.locationInWindow fromView:nil];
    const auto frame_coors = ToFrameCoords(view_coords);
    int line_no = m_Frame->LineIndexForPosition(frame_coors);
    if( line_no < 0 || line_no >= m_Frame->LinesNumber() )
        return;
    
    const auto &i = m_Frame->Line(line_no);
    const int sel_start_byte = i.BytesStart();
    const int sel_end_byte = i.BytesEnd();

    m_View.selectionInFile = CFRangeMake(sel_start_byte + m_Data->FilePos(),
                                         sel_end_byte - sel_start_byte);
}

void BigFileViewText::HandleSelectionWithDoubleClick(NSEvent* event)
{
    const auto view_coords = [m_View convertPoint:event.locationInWindow fromView:nil];
    const auto frame_coords = ToFrameCoords(view_coords);
    const auto [sel_start, sel_end] = m_Frame->WordRangeForPosition(frame_coords);
    const auto sel_start_byte = m_WorkingSet->ToGlobalByteOffset(sel_start);
    const auto sel_end_byte = m_WorkingSet->ToGlobalByteOffset(sel_end);
    m_View.selectionInFile = CFRangeMake(sel_start_byte, sel_end_byte - sel_start_byte);
}

void BigFileViewText::HandleSelectionWithMouseDragging(NSEvent* event)
{
    bool modifying_existing_selection = (event.modifierFlags & NSShiftKeyMask) ? true : false;
    
    const auto first_down_view_coords = [m_View convertPoint:event.locationInWindow fromView:nil];
    const auto first_down_frame_coords = ToFrameCoords(first_down_view_coords);
    const auto first_ind = m_Frame->CharIndexForPosition( first_down_frame_coords );
    
    CFRange orig_sel = [m_View SelectionWithinWindowUnichars];
    
    while ( event.type != NSLeftMouseUp ) {
        NSPoint curr_loc = [m_View convertPoint:event.locationInWindow fromView:nil];
        const auto curr_frame_coords = ToFrameCoords(curr_loc);
        const int curr_ind = m_Frame->CharIndexForPosition(curr_frame_coords);
        
        int base_ind = first_ind;
        if(modifying_existing_selection && orig_sel.length > 0)
        {
            if(first_ind > orig_sel.location && first_ind <= orig_sel.location + orig_sel.length)
                base_ind =
                first_ind - orig_sel.location > orig_sel.location + orig_sel.length - first_ind ?
                (int)orig_sel.location : (int)orig_sel.location + (int)orig_sel.length;
            else if(first_ind < orig_sel.location + orig_sel.length && curr_ind < orig_sel.location + orig_sel.length)
                base_ind = (int)orig_sel.location + (int)orig_sel.length;
            else if(first_ind > orig_sel.location && curr_ind > orig_sel.location)
                base_ind = (int)orig_sel.location;
        }
        
        if(base_ind != curr_ind)
        {
            int sel_start = base_ind > curr_ind ? curr_ind : base_ind;
            int sel_end   = base_ind < curr_ind ? curr_ind : base_ind;
            long sel_start_byte = m_WorkingSet->ToGlobalByteOffset(sel_start);
            long sel_end_byte = m_WorkingSet->ToGlobalByteOffset(sel_end);
            assert(sel_end_byte >= sel_start_byte);
            m_View.selectionInFile = CFRangeMake(sel_start_byte, sel_end_byte - sel_start_byte);
        }
        else
            m_View.selectionInFile = CFRangeMake(-1,0);
        
        event = [m_View.window nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
    }
}

}
