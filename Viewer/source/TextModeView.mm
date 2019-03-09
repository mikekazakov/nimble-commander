#include "TextModeView.h"
#include "TextProcessing.h"
#include "IndexedTextLine.h"
#include "TextModeWorkingSet.h"
#include "TextModeFrame.h"

#include <cmath>

#include <iostream>

using namespace nc;
using namespace nc::viewer;
using nc::utility::FontGeometryInfo;

static const auto g_TabSpaces = 4;
static const auto g_WrappingWidth = 10000.;
static const auto g_LeftInset = 5.;

static std::shared_ptr<const TextModeWorkingSet> MakeEmptyWorkingSet();
static std::shared_ptr<const TextModeWorkingSet>
    BuildWorkingSetForBackendState(const BigFileViewDataBackend& _backend);
static int FindEqualVerticalOffsetForRebuiltFrame
    (const TextModeFrame& old_frame,
     int old_vertical_offset,
     const TextModeFrame& new_frame);

@implementation NCViewerTextModeView
{
    const BigFileViewDataBackend *m_Backend;
    const Theme *m_Theme;
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::shared_ptr<const TextModeFrame> m_Frame;
    bool m_WordWrap;
    FontGeometryInfo m_FontInfo;
    
    int m_VerticalLineOffset; // offset in lines number within existing text lines in Frame
    CGPoint m_PxOffset; // smooth offset in pixels
    bool m_TrueScrolling; // true if the scrollbar is based purely on px offset and the entire
                          // file is layed out in a single frame.
}

- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(const BigFileViewDataBackend&)_backend
                        theme:(const nc::viewer::Theme&)_theme
{
    if( self = [super initWithFrame:_frame] ) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        m_Backend = &_backend;
        m_Theme = &_theme;
        m_WorkingSet = MakeEmptyWorkingSet();
        m_WordWrap = true;
        m_FontInfo = FontGeometryInfo{ (__bridge CTFontRef)m_Theme->Font() };
        m_VerticalLineOffset = 0;
        m_PxOffset = CGPointMake(0., 0.);
        m_TrueScrolling = _backend.IsFullCoverage();
        [self backendContentHasChanged];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
    }
    
    return self;
}

- (BOOL)isFlipped
{
    return true;
}

- (BOOL) acceptsFirstResponder
{
    return true;
}

- (void)backendContentHasChanged
{
    m_WorkingSet = BuildWorkingSetForBackendState(*m_Backend);
    m_Frame = [self buildLayout];
}

- (NSSize)contentsSize
{
    return self.bounds.size;
}

- (double)wrappingWidth
{
    // TODO: replace self.bounds with a more precide measurement
    const auto wrapping_width = m_WordWrap ?
        self.bounds.size.width - g_LeftInset :
        g_WrappingWidth;
    return wrapping_width;
}

- (std::shared_ptr<const TextModeFrame>)buildLayout
{
    const auto wrapping_width = [self wrappingWidth];
 
    TextModeFrame::Source source;
    source.wrapping_width = wrapping_width;
    source.font = (__bridge CTFontRef)m_Theme->Font();
    source.font_info = m_FontInfo;
    source.foreground_color = m_Theme->TextColor().CGColor;
    source.tab_spaces = g_TabSpaces;
    source.working_set = m_WorkingSet;
    return std::make_shared<TextModeFrame>(source);
}

//
//CGPoint BigFileViewText::ToFrameCoords(CGPoint _view_coords)
//{
//    CGPoint left_upper = TextAnchor();
//    return CGPointMake(_view_coords.x - left_upper.x,
//                       left_upper.y - _view_coords.y + m_VerticalOffset * m_FontInfo.LineHeight());
//}

/**
 * Returns local view coordinates of the left-top corner of text.
 * Does move on both vertical and horizontal movement.
 */
- (CGPoint)textOrigin
{
    const auto origin = CGPointMake(5., 5.);
    const auto vertical_shift = -1. * m_VerticalLineOffset * m_FontInfo.LineHeight()
        - m_PxOffset.y;
    return CGPointMake(origin.x, origin.y + vertical_shift);
}

/**
* Returns a number of lines which could be fitted into the view.
* This is a floor estimation, i.e. number of fully fitting lines.
*/
- (int)numberOfLinesFittingInView
{
    const auto vertical_lines = (int)std::floor(self.contentsSize.height / m_FontInfo.LineHeight());
    return vertical_lines;
}

- (void)drawRect:(NSRect)_dirty_rect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    
    CGContextSetFillColorWithColor(context, m_Theme->ViewerBackgroundColor().CGColor );
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    CGAffineTransform transform;
    transform.a = 1.;
    transform.b = 0.;
    transform.c = 0.;
    transform.d = -1.;
    transform.tx = 0.;
    transform.ty = 0.;
    CGContextSetTextMatrix(context, transform);
    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGContextSetShouldSmoothFonts(context, true);
    CGContextSetShouldAntialias(context, true);
    
//    CGPoint pos = TextAnchor();
    const auto origin = [self textOrigin];
//    std::cout << origin.y << std::endl;
//    auto line_pos = origin;
//    pos.y = pos.y - m_FontInfo.LineHeight() + m_FontInfo.Descent();
//    pos.y = pos.y + m_FontInfo.LineHeight() - m_FontInfo.Descent();
    
    // TODO: replace self.bounds with a more precide measurement
//    double view_width = self.bounds.size.width;
    
    const auto lines_per_screen =
        (int)std::ceil( self.bounds.size.height / m_FontInfo.LineHeight() );
    
    // both lines_start and lines_end are _not_ clamped regarding real Frame data!
    const int lines_start = (int)std::floor( (0. - origin.y) / m_FontInfo.LineHeight() );
    const int lines_end = lines_start + lines_per_screen;
//    line_pos.y = line_pos.y + lines_start * m_FontInfo.LineHeight();
    auto line_pos = CGPointMake( origin.x, origin.y + lines_start * m_FontInfo.LineHeight() );
    
//    if( m_SmoothOffset.y < 0 && first_string > 0 ) {
//        --first_string; // to be sure that we can see bottom-clipped lines
//        pos.y += m_FontInfo.LineHeight();
//    }
    
//    CFRange selection = [m_View SelectionWithinWindowUnichars];
    
    for( int line_no = lines_start;
         line_no < lines_end;
         ++line_no, line_pos.y += m_FontInfo.LineHeight() ) {
        const auto text_origin = CGPointMake
            ( line_pos.x, line_pos.y + m_FontInfo.LineHeight() - m_FontInfo.Descent() );
//        auto &line = m_Frame->Line(i);
        
//        if(selection.location >= 0) // draw a selection background here
//        {
//            CGFloat x1 = 0, x2 = -1;
//            if(line.UniCharsStart() <= selection.location &&
//               line.UniCharsEnd() > selection.location )
//            {
//                x1 = pos.x + CTLineGetOffsetForStringIndex(line.Line(), selection.location, 0);
//                x2 = ((selection.location + selection.length <= line.UniCharsEnd()) ?
//                      pos.x + CTLineGetOffsetForStringIndex(line.Line(),
//                                                            (selection.location + selection.length <= line.UniCharsEnd()) ?
//                                                            selection.location + selection.length : line.UniCharsEnd(),
//                                                            0) : view_width);
//            }
//            else if(selection.location + selection.length > line.UniCharsStart() &&
//                    selection.location + selection.length <= line.UniCharsEnd() )
//            {
//                x1 = pos.x;
//                x2 = pos.x + CTLineGetOffsetForStringIndex(line.Line(), selection.location + selection.length, 0);
//            }
//            else if(selection.location < line.UniCharsStart() &&
//                    selection.location + selection.length > line.UniCharsEnd() )
//            {
//                x1 = pos.x;
//                x2 = view_width;
//            }
//
//            if(x2 > x1)
//            {
//                CGContextSaveGState(_context);
//                CGContextSetShouldAntialias(_context, false);
//                //m_View.SelectionBkFillColor.Set(_context);
//                CGContextSetFillColorWithColor(_context, m_View.SelectionBkFillColor);
//                CGContextFillRect(_context, CGRectMake(x1, pos.y - m_FontInfo.Descent(), x2 - x1, m_FontInfo.LineHeight()));
//                CGContextRestoreGState(_context);
//            }
//        }
        
        if( line_no >= 0 && line_no < m_Frame->LinesNumber() ) {
            auto &line = m_Frame->Line(line_no);
            CGContextSetTextPosition( context, text_origin.x, text_origin.y );
            CTLineDraw(line.Line(), context );
        }
    }
}

- (bool)doMoveUpByOneLine
{
    if( m_VerticalLineOffset > 0 ) {
        m_VerticalLineOffset--;
        [self setNeedsDisplay:true];
        return true;
    }
    else if( [self canMoveFileWindowUp] ) {
        assert( self.delegate );
        const auto old_frame = m_Frame;
        const auto old_anchor_line_index  = std::clamp( m_VerticalLineOffset,
                                                       0,
                                                       old_frame->LinesNumber() - 1 );
        const auto old_anchor_glob_offset =
        (long)old_frame->Line(old_anchor_line_index).BytesStart() +
        old_frame->WorkingSet().GlobalOffset();
        const auto desired_window_offset = std::clamp
        (old_anchor_glob_offset - (int64_t)m_Backend->RawSize() + (int64_t)m_Backend->RawSize() / 4,
         (int64_t)0,
         (int64_t)(m_Backend->FileSize() - m_Backend->RawSize()) );
        
        const auto rc = [self.delegate textModeView:self
                requestsSyncBackendWindowMovementAt:desired_window_offset];
        if( rc != VFSError::Ok )
            return false;
        
        [self backendContentHasChanged];
        
        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame,
                                                                      m_VerticalLineOffset,
                                                                      *old_frame);
        if( m_VerticalLineOffset > 0 )
            m_VerticalLineOffset--;
        [self setNeedsDisplay:true];
        return true;
    }
    else {
        return false;
    }
}

- (bool)canMoveFileWindowUp
{
    return m_Backend->FilePos() > 0;
}

- (bool)canMoveFileWindowDown
{
    return m_Backend->FilePos() + m_Backend->RawSize() < m_Backend->FileSize();
}

- (bool)doMoveDownByOneLine
{
    if( m_VerticalLineOffset + self.numberOfLinesFittingInView < m_Frame->LinesNumber()  ) {
        m_VerticalLineOffset++;
        [self setNeedsDisplay:true];
        return true;
    }
    else if( [self canMoveFileWindowDown] ) {
        assert( self.delegate );
        const auto old_frame = m_Frame;
        const auto old_anchor_line_index  = std::clamp( m_VerticalLineOffset,
                                                       0,
                                                       old_frame->LinesNumber() - 1 );
        const auto old_anchor_glob_offset =
            (long)old_frame->Line(old_anchor_line_index).BytesStart() +
            old_frame->WorkingSet().GlobalOffset();
        const auto desired_window_offset = std::clamp
            (old_anchor_glob_offset - (int64_t)m_Backend->RawSize() / 4,
             (int64_t)0,
             (int64_t)(m_Backend->FileSize() - m_Backend->RawSize()) );
        if( desired_window_offset <= (int64_t)m_Backend->FilePos() )
            return false; // singular situation. don't handle for now.
        
        const auto rc = [self.delegate textModeView:self
                requestsSyncBackendWindowMovementAt:desired_window_offset];
        if( rc != VFSError::Ok )
            return false;
        
        [self backendContentHasChanged];
        
        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame,
                                                                      m_VerticalLineOffset,
                                                                      *old_frame);
        if( m_VerticalLineOffset + self.numberOfLinesFittingInView < m_Frame->LinesNumber() )
            m_VerticalLineOffset++;
//        std::cout << m_WorkingSet->GlobalOffset() << std::endl;
        [self setNeedsDisplay:true];
        return true;
    }
    else {
        return false;
    }
}
//
//if( m_VerticalOffset + _delta + m_FrameLines < lines_number ) {
//    // ok, just scroll within current window
//    m_VerticalOffset += _delta;
//}
//else {
//    // nope, we need to move file window if it is possible
//    if(window_pos + window_size < file_size)
//    { // ok, can move - there's a space
//        int anchor_index = std::min(m_VerticalOffset + _delta - 1,
//                                    lines_number - 1);
//        int anchor_pos_on_screen = -1;
//
//        uint64_t anchor_glob_offset = m_Frame->Line(anchor_index).BytesStart() + window_pos;
//
//        assert(anchor_glob_offset > window_size/4); // internal logic check
//        // TODO: need something more intelligent here
//        uint64_t desired_window_offset = anchor_glob_offset - window_size/4;
//        desired_window_offset = std::clamp(desired_window_offset, 0ull, file_size - window_size);
//
//        MoveFileWindowTo(desired_window_offset, anchor_glob_offset, anchor_pos_on_screen);
//    }
//    else
//    { // just move offset to the end within our window
//        if(m_VerticalOffset + m_FrameLines < lines_number)
//            m_VerticalOffset = lines_number - m_FrameLines;
//    }
//}

- (void)moveUp:(id)sender
{
    [self doMoveUpByOneLine];
}

- (void)moveDown:(id)sender
{
    [self doMoveDownByOneLine];
}

/**
 * Returns true if either the line offset is greater than zero or
 * the backend window position is not at the beginning of the file.
 */
- (bool) canScrollUp
{
    return m_VerticalLineOffset > 0 || m_Backend->FilePos() > 0;
}

- (bool) canScrollDown
{
    return
        (m_Backend->FilePos() + m_Backend->RawSize() < m_Backend->FileSize()) ||
        (m_VerticalLineOffset + self.numberOfLinesFittingInView < m_Frame->LinesNumber());
}

- (void)scrollWheel:(NSEvent *)_event
{
    const auto delta_y = _event.hasPreciseScrollingDeltas ?
        _event.scrollingDeltaY :
        _event.scrollingDeltaY * m_FontInfo.LineHeight();
//    const auto delta_x = _event.hasPreciseScrollingDeltas ?
//        _event.scrollingDeltaX :
//        _event.scrollingDeltaX * m_FontInfo.MonospaceWidth();

    if( delta_y > 0 ) { // going up
        if( [self canScrollUp] ) {
            [self setNeedsDisplay:true];
            auto px_offset = m_PxOffset.y - delta_y;
            m_PxOffset.y = 0;
            while( px_offset <= -m_FontInfo.LineHeight() ) {
                const auto did_move = [self doMoveUpByOneLine];
                if( did_move == false )
                    break;
                px_offset += m_FontInfo.LineHeight();
            }
            m_PxOffset.y = std::clamp( px_offset, -m_FontInfo.LineHeight(), 0. );
        }
        else {
            m_PxOffset.y = std::max( m_PxOffset.y - delta_y, 0.0 );
            [self setNeedsDisplay:true];
        }
    }
    if( delta_y < 0 ) { // going down
        if( [self canScrollDown] ) {
            [self setNeedsDisplay:true];
            auto px_offset = m_PxOffset.y - delta_y;
            m_PxOffset.y = 0;
            while( px_offset >= m_FontInfo.LineHeight() ) {
                const auto did_move = [self doMoveDownByOneLine];
                if( did_move == false )
                    break;
                px_offset -= m_FontInfo.LineHeight();
            }
            m_PxOffset.y = std::clamp( px_offset, 0., m_FontInfo.LineHeight() );
        }
        else {
            m_PxOffset.y = std::clamp(m_PxOffset.y - delta_y, -m_FontInfo.LineHeight(), 0.);
            [self setNeedsDisplay:true];
        }
    }
    assert( std::abs(m_PxOffset.y) <= m_FontInfo.LineHeight() );

}


- (void)frameDidChange
{
    if( [self shouldRebuilFrameForChangedFrame] ) {
        const auto new_frame = [self buildLayout];
        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame,
                                                                  m_VerticalLineOffset,
                                                                  *new_frame);
        m_Frame = new_frame;
    }
    [self setNeedsDisplay:true];
}

- (bool)shouldRebuilFrameForChangedFrame
{
    const auto current_wrapping_width = [self wrappingWidth];
    return m_Frame->WrappingWidth() != current_wrapping_width;
}

@end

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

static std::shared_ptr<const TextModeWorkingSet> BuildWorkingSetForBackendState
    (const BigFileViewDataBackend& _backend)
{
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = (const char16_t*)_backend.UniChars();
    source.mapping_to_byte_offsets = (const int*)_backend.UniCharToByteIndeces();
    source.characters_number = _backend.UniCharsSize();
    source.bytes_offset = (long)_backend.FilePos();
    source.bytes_length = (int)_backend.RawSize();
    return std::make_shared<TextModeWorkingSet>(source);
}

static int FindEqualVerticalOffsetForRebuiltFrame
    (const TextModeFrame& old_frame,
     const int old_vertical_offset,
     const TextModeFrame& new_frame)
{
    if( &old_frame.WorkingSet() == &new_frame.WorkingSet() ) {
        if( old_vertical_offset < 0 ) {
            // offseting the old frame before the first line => offset remains the same
            return old_vertical_offset;
        }
        else if( old_vertical_offset >= old_frame.LinesNumber() ) {
            // offseting the old frame after the last line => keep the delta the same
            const auto delta_offset = old_vertical_offset - old_frame.LinesNumber();
            return new_frame.LinesNumber() + delta_offset;
        }
        else {
            // some old line was an offset target - find the closest equivalent line in the
            // new frame.
            const auto &old_line = old_frame.Line(old_vertical_offset);
            const auto old_byte_offset = old_line.BytesStart();
            const auto closest = FindClosestLineIndex
            (new_frame.Lines().data(),
             new_frame.Lines().data() + new_frame.LinesNumber(),
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
        else if( old_vertical_offset >= old_frame.LinesNumber() ) {
            // offseting the old frame after the last line => find the equivalent line
            // and offset that one by the same lines delta
            const auto delta_offset = old_vertical_offset - old_frame.LinesNumber();
            if( old_frame.LinesNumber() == 0 )
                return delta_offset;
            const auto &last_old_line = old_frame.Line( old_frame.LinesNumber() - 1 );
            const auto old_byte_offset = last_old_line.BytesStart();
            const auto new_byte_offset= old_byte_offset + old_global_offset - new_global_offset;
            if( new_byte_offset < 0 || new_byte_offset > std::numeric_limits<int>::max() )
                return 0; // can't possibly satisfy
            const auto closest = FindClosestLineIndex
            (new_frame.Lines().data(),
             new_frame.Lines().data() + new_frame.LinesNumber(),
             (int)new_byte_offset);
            return closest + delta_offset;
        }
        else {
            // general case - get the line and find the closest in the new frame
            const auto &old_line = old_frame.Line( old_vertical_offset );
            const auto old_byte_offset = old_line.BytesStart();
            const auto new_byte_offset = old_byte_offset + old_global_offset - new_global_offset;
            if( new_byte_offset < 0 || new_byte_offset > std::numeric_limits<int>::max() )
                return 0; // can't possibly satisfy
            const auto closest = FindClosestLineIndex
            (new_frame.Lines().data(),
             new_frame.Lines().data() + new_frame.LinesNumber(),
             (int)new_byte_offset);
            return closest;
        }
    }
}
