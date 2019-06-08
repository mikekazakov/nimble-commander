// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "HexModeView.h"
#include "HexModeFrame.h"
#include "HexModeLayout.h"

#include <Habanero/algo.h>
#include <Habanero/CFRange.h>
#include <Habanero/mach_time.h>

#include <iostream>
#include <cmath>


using namespace nc;
using namespace nc::viewer;
using nc::utility::FontGeometryInfo;

static const auto g_TopInset = 1.;

static std::shared_ptr<const TextModeWorkingSet> MakeEmptyWorkingSet();
static std::shared_ptr<const TextModeWorkingSet>
    BuildWorkingSetForBackendState(const DataBackend& _backend);

@implementation NCViewerHexModeView
{
    const DataBackend *m_Backend;
    const Theme *m_Theme;
    NSScrollView *m_ScrollView;
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::shared_ptr<const HexModeFrame> m_Frame;
    FontGeometryInfo m_FontInfo;
    std::unique_ptr<HexModeLayout> m_Layout;
    NSScroller *m_VerticalScroller;
}

- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(const DataBackend&)_backend
                        theme:(const nc::viewer::Theme&)_theme
{
    if( self = [super initWithFrame:_frame] ) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        m_Backend = &_backend;
        m_Theme = &_theme;
        m_FontInfo = FontGeometryInfo{ (__bridge CTFontRef)m_Theme->Font() };
        m_WorkingSet = MakeEmptyWorkingSet();
        m_Frame = [self buildFrame];
        
        HexModeLayout::Source layout_source;
        layout_source.file_size = (long)m_Backend->FileSize();
        layout_source.frame = m_Frame;
        layout_source.view_size = self.frame.size;
        layout_source.scroll_offset = HexModeLayout::ScrollOffset{};
        m_Layout = std::make_unique<HexModeLayout>(layout_source);
        
        m_VerticalScroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, 15, 100)];
        m_VerticalScroller.enabled = true;
        m_VerticalScroller.target = self;
        m_VerticalScroller.action = @selector(onVerticalScroll:);
        m_VerticalScroller.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_VerticalScroller];
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_VerticalScroller);
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"[m_VerticalScroller(15)]-(0)-|"
                                                 options:0 metrics:nil views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_VerticalScroller]-(0)-|"
                                                 options:0 metrics:nil views:views]];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
        [self backendContentHasChanged];
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

- (void)viewDidMoveToSuperview
{
    if( self.superview != nil ) {
        if( self.delegate == nil ) {
            throw std::logic_error("HexModeView was inserted without a delegete to work with");
        }
    }
}

- (void)backendContentHasChanged
{
    [self rebuildWorkingSetAndFrame];
}

- (void)rebuildWorkingSetAndFrame
{
    m_WorkingSet = BuildWorkingSetForBackendState(*m_Backend);
    
    m_Frame = [self buildFrame];
    
    m_Layout->SetFrame(m_Frame);
    [self setNeedsDisplay:true];
    [self scrollPositionDidChange];
}

- (std::shared_ptr<const HexModeFrame>)buildFrame
{
    HexModeFrame::Source source;
    source.font = (__bridge CTFontRef)m_Theme->Font();
    source.font_info = m_FontInfo;
    source.foreground_color = m_Theme->TextColor().CGColor;
    source.working_set = m_WorkingSet;
    source.raw_bytes_begin = (const std::byte *)m_Backend->Raw();
    source.raw_bytes_end = (const std::byte *)m_Backend->Raw() + m_Backend->RawSize();
    source.number_of_columns = 2;
    source.bytes_per_column = 8;

    return std::make_shared<HexModeFrame>(source);
}

- (void)syncVerticalScrollerPosition
{
    const auto scroll_pos = m_Layout->CalcScrollerPosition();
    m_VerticalScroller.doubleValue = scroll_pos.position;
    m_VerticalScroller.knobProportion = scroll_pos.proportion;
}

- (void)moveUp:(id)[[maybe_unused]]_sender
{
    m_Layout->SetOffset(m_Layout->GetOffset().WithoutSmoothOffset());
    [self doMoveUpByOneLine];
    [self scrollPositionDidChange];
}

- (void)moveDown:(id)[[maybe_unused]]_sender
{
    m_Layout->SetOffset(m_Layout->GetOffset().WithoutSmoothOffset());
    [self doMoveDownByOneLine];
    [self scrollPositionDidChange];
}

- (void)pageDown:(nullable id)[[maybe_unused]]_sender
{
    m_Layout->SetOffset(m_Layout->GetOffset().WithoutSmoothOffset());
    int lines_to_scroll = m_Layout->RowsInView();
    while ( lines_to_scroll --> 0 )
        [self doMoveDownByOneLine];
    [self scrollPositionDidChange];
}

- (void)pageUp:(nullable id)[[maybe_unused]]_sender
{
    m_Layout->SetOffset(m_Layout->GetOffset().WithoutSmoothOffset());
    int lines_to_scroll = m_Layout->RowsInView();
    while ( lines_to_scroll --> 0 )
        [self doMoveUpByOneLine];
    [self scrollPositionDidChange];
}

- (void)onVerticalScroll:(id)_sender
{
    switch( m_VerticalScroller.hitPart ) {
        case NSScrollerIncrementLine:
            [self moveDown:_sender];
            break;
        case NSScrollerIncrementPage:
            [self pageDown:_sender];
            break;
        case NSScrollerDecrementLine:
            [self moveUp:_sender];
            break;
        case NSScrollerDecrementPage:
            [self pageUp:_sender];
            break;
        case NSScrollerKnob: {
            auto scroller_pos = HexModeLayout::ScrollerPosition{m_VerticalScroller.doubleValue,
                m_VerticalScroller.knobProportion};
            const auto offset =  m_Layout->CalcGlobalOffsetForScrollerPosition( scroller_pos );
            [self scrollToGlobalBytesOffset:offset];
            break;
        }
        default:
            break;
    }
}

/**
 * Returns local view coordinates of the left-top corner of text.
 * Does move on both vertical movement.
 */
- (CGPoint)textOrigin
{
    const auto origin = CGPointMake(m_Layout->GetGaps().left_inset, g_TopInset);
    const auto offset = m_Layout->GetOffset();
    const auto vertical_shift = offset.row * m_FontInfo.LineHeight() + offset.smooth;
    return CGPointMake(origin.x, origin.y - vertical_shift);
}

- (void)drawRect:(NSRect)dirtyRect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetFillColorWithColor(context, m_Theme->ViewerBackgroundColor().CGColor );
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    
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

    const auto origin = [self textOrigin];

    const auto lines_per_screen =
        (int)std::ceil( self.bounds.size.height / m_FontInfo.LineHeight() );
    const int lines_start = (int)std::floor( (0. - origin.y) / m_FontInfo.LineHeight() );

    // +1 to ensure that selection of a following line is also visible
    const int lines_end = lines_start + lines_per_screen + 1;
    
    const auto bytes_selection = [self localBytesSelection];
    const auto chars_selection = [self localCharsSelection];    
    const auto offsets = m_Layout->CalcHorizontalOffsets();
    const auto line_height = m_Frame->FontInfo().LineHeight();
    
    auto line_pos = CGPointMake( origin.x, origin.y + lines_start * m_FontInfo.LineHeight() );
    for( int row_index = lines_start; row_index < lines_end;
        ++row_index, line_pos.y += line_height ) {
        if( row_index < 0 || row_index >= m_Frame->NumberOfRows() )
            continue;
        
        const auto text_origin = CGPointMake(line_pos.x,
                                             line_pos.y +
                                             m_Frame->FontInfo().LineHeight() -
                                             m_Frame->FontInfo().Descent() );
        
        auto &row = m_Frame->RowAtIndex(row_index);
        
        // address
        CGContextSetTextPosition( context, offsets.address, text_origin.y );
        CTLineDraw(row.AddressLine(), context );
        
        // columns
        for( int column_index = 0; column_index < row.ColumnsNumber(); ++column_index ) {
            const auto sel_bg = m_Layout->CalcColumnSelectionBackground(bytes_selection,
                                                                        row_index,
                                                                        column_index,
                                                                        offsets); 
            if( sel_bg.first < sel_bg.second )
                [self highlightSelectionWithRect:CGRectMake(sel_bg.first,
                                                            line_pos.y,
                                                            sel_bg.second - sel_bg.first,
                                                            line_height)];

            CGContextSetTextPosition( context, offsets.columns.at(column_index), text_origin.y );
            CTLineDraw(row.ColumnLine(column_index), context );
        }

        // snippet
        const auto sel_bg = m_Layout->CalcSnippetSelectionBackground(chars_selection,
                                                                     row_index, 
                                                                     offsets);
        if( sel_bg.first < sel_bg.second )
            [self highlightSelectionWithRect:CGRectMake(sel_bg.first,
                                                        line_pos.y,
                                                        sel_bg.second - sel_bg.first,
                                                        line_height)];        
        CGContextSetTextPosition( context, offsets.snippet, text_origin.y );        
        CTLineDraw(row.SnippetLine(), context );
    }
}

- (void)highlightSelectionWithRect:(CGRect)_rc
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context, false);
    CGContextSetFillColorWithColor(context, m_Theme->ViewerSelectionColor().CGColor);
    CGContextFillRect(context, _rc);
    CGContextRestoreGState(context);
}

- (void)drawFocusRingMask
{
    NSRectFill(self.focusRingMaskBounds);
}

- (NSRect)focusRingMaskBounds
{
    return self.bounds;
}

- (void)frameDidChange
{
    m_Layout->SetViewSize(self.frame.size);
    [self scrollPositionDidChange];
}

/**
 * Non-binding request to show content located at the '_offset' position within the file.
 */
- (bool)scrollToGlobalBytesOffset:(int64_t)_offset
{
    
    auto probe_instant = m_Layout->FindRowToScrollWithGlobalOffset(_offset);
    
    if( probe_instant != std::nullopt ) {
        // great, can satisfy the request instantly
        m_Layout->SetOffset({*probe_instant, 0.});

        [self setNeedsDisplay:true];
        [self scrollPositionDidChange];
        return true;
    }
    else {
        // nope, we need to perform I/O to move the file window
        const auto desired_wnd_pos = std::clamp
        (_offset - (int64_t)m_Backend->RawSize() / 2,
         (int64_t)0,
         (int64_t)m_Backend->FileSize() - (int64_t)m_Backend->RawSize());

        const auto rc = [self.delegate hexModeView:self
                requestsSyncBackendWindowMovementAt:desired_wnd_pos];
        if( rc != VFSError::Ok )
            return false;

        [self rebuildWorkingSetAndFrame];

        auto second_probe = m_Layout->FindRowToScrollWithGlobalOffset(_offset);
        if( second_probe != std::nullopt ) {
            m_Layout->SetOffset({*second_probe, 0.});

            [self setNeedsDisplay:true];
            [self scrollPositionDidChange];
            return true;
        }
        else {
            // this shouldn't happen... famous last words.
            return false;
        }
    }

    return false;
}

- (void)scrollPositionDidChange
{
    [self syncVerticalScrollerPosition];
    
    if( self.delegate ) { // this can be called from the constructor where we don't have a delegate
        const auto bytes_position = m_Layout->CalcGlobalOffset();
        const auto scroll_position = m_VerticalScroller.doubleValue;        
        [self.delegate hexModeView:self
     didScrollAtGlobalBytePosition:bytes_position
              withScrollerPosition:scroll_position];
    }
}


/**
 * Returns true if either the row offset is greater than zero or
 * the working set global position is not at the beginning of the file.
 */
- (bool) canScrollUp
{
    return m_Layout->GetOffset().row  > 0 || m_WorkingSet->GlobalOffset() > 0;
}

/**
 * Returns true if either the backend is not positioned at the bottom of the file or
 * there's something to show in the backend below current screen position.
 */
- (bool) canScrollDown
{
    return
    (m_Backend->FilePos() + m_Backend->RawSize() < m_Backend->FileSize()) ||
    (m_Layout->GetOffset().row + m_Layout->RowsInView() < m_Frame->NumberOfRows());
}

- (bool)canMoveFileWindowUp
{
    return m_Backend->FilePos() > 0;
}

- (bool)canMoveFileWindowDown
{
    return m_Backend->FilePos() + m_Backend->RawSize() < m_Backend->FileSize();
}

- (bool)doMoveUpByOneLine
{
    auto scroll_offset = m_Layout->GetOffset();
    if( scroll_offset.row > 0 ) {
        scroll_offset.row--;
        m_Layout->SetOffset(scroll_offset);
        [self setNeedsDisplay:true];
        return true;
    }
    else if( [self canMoveFileWindowUp] ) {
        const auto old_frame = m_Frame;
        const auto old_anchor_row_index  = std::clamp( scroll_offset.row,
                                                       0,
                                                       old_frame->NumberOfRows() - 1 );
        const auto old_anchor_glob_offset =
            (long)old_frame->RowAtIndex(old_anchor_row_index).BytesStart() +
            old_frame->WorkingSet().GlobalOffset();
        const auto desired_window_offset = std::clamp(old_anchor_glob_offset -
                                                      (int64_t)m_Backend->RawSize() +
                                                      (int64_t)m_Backend->RawSize() / 4,
                                                      (int64_t)0,
                                                      (int64_t)(m_Backend->FileSize() -
                                                                m_Backend->RawSize()) );
        
        const auto rc = [self.delegate hexModeView:self
                requestsSyncBackendWindowMovementAt:desired_window_offset];
        if( rc != VFSError::Ok )
            return false;
        
        [self rebuildWorkingSetAndFrame];
        
        auto new_offset = HexModeLayout::FindEqualVerticalOffsetForRebuiltFrame(*old_frame,
                                                                                scroll_offset.row,
                                                                                *m_Frame);
        if( new_offset > 0 )
            new_offset--;
    
        m_Layout->SetOffset({new_offset, scroll_offset.smooth});
        [self setNeedsDisplay:true];
                
        return true;
    }
    else {
        return false;
    }
}

- (bool)doMoveDownByOneLine
{
    auto scroll_offset = m_Layout->GetOffset();    
    if( scroll_offset.row + m_Layout->RowsInView() < m_Frame->NumberOfRows() ) {
        scroll_offset.row++;
        m_Layout->SetOffset(scroll_offset);
        [self setNeedsDisplay:true];
        return true;
    }
    else if( [self canMoveFileWindowDown] ) {
        const auto old_frame = m_Frame;
        const auto old_anchor_row_index  = std::clamp( scroll_offset.row,
                                                      0,
                                                      old_frame->NumberOfRows() - 1 );
        const auto old_anchor_glob_offset =
        (long)old_frame->RowAtIndex(old_anchor_row_index).BytesStart() +
        old_frame->WorkingSet().GlobalOffset();
        const auto desired_window_offset = std::clamp(old_anchor_glob_offset +
                                                      (int64_t)m_Backend->RawSize() -
                                                      (int64_t)m_Backend->RawSize() / 4,
                                                      (int64_t)0,
                                                      (int64_t)(m_Backend->FileSize() -
                                                                m_Backend->RawSize()) );
        
        if( desired_window_offset <= (int64_t)m_Backend->FilePos() )
            return false; // singular situation. don't handle for now.
        
        const auto rc = [self.delegate hexModeView:self
               requestsSyncBackendWindowMovementAt:desired_window_offset];
        if( rc != VFSError::Ok )
            return false;
        
        [self rebuildWorkingSetAndFrame];
        
        auto new_offset = HexModeLayout::FindEqualVerticalOffsetForRebuiltFrame(*old_frame,
                                                                                scroll_offset.row,
                                                                                *m_Frame);
        if( scroll_offset.row + m_Layout->RowsInView() < m_Frame->NumberOfRows() )
            new_offset++;
        
        m_Layout->SetOffset({new_offset, scroll_offset.smooth});
        [self setNeedsDisplay:true];
        
        return true;
    }
    else {
        return false;
    }
}

- (void)scrollWheelVertical:(double)_delta_y
{
    [self setNeedsDisplay:true];
    const auto delta_y = _delta_y;
    if( delta_y > 0 ) { // going up
        double smooth_offset = m_Layout->GetOffset().smooth;
        if( [self canScrollUp] ) {
            smooth_offset -= delta_y;
            while( smooth_offset <= -m_FontInfo.LineHeight() ) {
                const auto did_move = [self doMoveUpByOneLine];
                if( did_move == false )
                    break;
                smooth_offset += m_FontInfo.LineHeight();
            }
            smooth_offset = std::clamp( smooth_offset, -m_FontInfo.LineHeight(), 0. );
        }
        else {
            smooth_offset = std::max( smooth_offset - delta_y, 0.0 );
        }
        m_Layout->SetOffset({m_Layout->GetOffset().row, smooth_offset});
    }
    if( delta_y < 0 ) { // going down
        double smooth_offset = m_Layout->GetOffset().smooth;
        if( [self canScrollDown] ) {
            smooth_offset -= delta_y;
            while( smooth_offset >= m_FontInfo.LineHeight() ) {
                const auto did_move = [self doMoveDownByOneLine];
                if( did_move == false )
                    break;
                smooth_offset -= m_FontInfo.LineHeight();
            }
            smooth_offset = std::clamp( smooth_offset, 0., m_FontInfo.LineHeight() );
        }
        else {
            smooth_offset = std::clamp(smooth_offset - delta_y, -m_FontInfo.LineHeight(), 0.);
        }
        m_Layout->SetOffset({m_Layout->GetOffset().row, smooth_offset});
    }
}

- (void)scrollWheel:(NSEvent *)_event
{
    const auto delta_y = _event.hasPreciseScrollingDeltas ?
    _event.scrollingDeltaY :
    _event.scrollingDeltaY * m_FontInfo.LineHeight();
    [self scrollWheelVertical:delta_y];
    
    [self scrollPositionDidChange];
}

- (void)keyDown:(NSEvent *)event
{
    if( event.charactersIgnoringModifiers.length != 1 ) {
        [super keyDown:event];
        return;
    }
    switch( [event.charactersIgnoringModifiers characterAtIndex:0] ) {
        case NSHomeFunctionKey:
            [self scrollToGlobalBytesOffset:int64_t(0)];
            break;
        case NSEndFunctionKey:
            [self scrollToGlobalBytesOffset:int64_t(m_Backend->FileSize())];
            break;
        default:
            [super keyDown:event];
            return;
    }
}

- (void) mouseDown:(NSEvent *)_event
{
    // TODO: selection with double- and triple- click
    [self handleSelectionWithMouseDragging:_event];
}

- (bool) shouldDoDraggingSelectionInColumns:(NSEvent*)_event
{
    const auto coords = [self convertPoint:_event.locationInWindow fromView:nil];
    const auto hit_part = m_Layout->HitTest(coords.x);
    if( hit_part == HexModeLayout::HitPart::Columns ||
        hit_part == HexModeLayout::HitPart::AddressColumsGap ) {
        return true;
    }
    if( hit_part == HexModeLayout::HitPart::ColumnsSnippetGap ) {
        const auto offsets = m_Layout->CalcHorizontalOffsets();
        if( offsets.snippet - coords.x > m_Layout->GetGaps().columns_snippet_gap / 2. )
            return true;
    }
    return false;
}

- (bool) shouldDoDraggingSelectionInSnippet:(NSEvent*)_event
{
    const auto coords = [self convertPoint:_event.locationInWindow fromView:nil];
    const auto hit_part = m_Layout->HitTest(coords.x);
    if( hit_part == HexModeLayout::HitPart::Snippet )
        return true;

    if( hit_part == HexModeLayout::HitPart::ColumnsSnippetGap ) {
        const auto offsets = m_Layout->CalcHorizontalOffsets();
        if( offsets.snippet - coords.x < m_Layout->GetGaps().columns_snippet_gap / 2. )
            return true;
    }
    return false;
}

- (void) handleSelectionWithMouseDragging:(NSEvent*)_event
{
    const auto event_mask = NSLeftMouseDraggedMask | NSLeftMouseUpMask;
    const auto modifying_existing_selection = bool(_event.modifierFlags & NSShiftKeyMask);
    const auto first_down_view_coords = [self convertPoint:_event.locationInWindow fromView:nil];
    if( [self shouldDoDraggingSelectionInColumns:_event] ) {
        const auto first_ind = m_Layout->ByteOffsetFromColumnHit(first_down_view_coords);
        const auto original_selection = [self localBytesSelection];
        for( auto event = _event; event && event.type != NSLeftMouseUp;
            event = [self.window nextEventMatchingMask:event_mask] ) {
            const auto curr_view_coords = [self convertPoint:event.locationInWindow fromView:nil];
            const auto curr_ind = m_Layout->ByteOffsetFromColumnHit(curr_view_coords);
            const auto selection = HexModeLayout::MergeSelection(original_selection, 
                                                                 modifying_existing_selection, 
                                                                 first_ind, 
                                                                 curr_ind);
            if( selection.first != selection.second ) {
                const auto global = CFRangeMake(selection.first + m_WorkingSet->GlobalOffset(),
                                                selection.second - selection.first);
                [self.delegate hexModeView:self setSelection:global];
            }
            else
                [self.delegate hexModeView:self setSelection:CFRangeMake(-1,0)];
        }
    }
    else if( [self shouldDoDraggingSelectionInSnippet:_event] ) {
        const auto first_ind = m_Layout->CharOffsetFromSnippetHit(first_down_view_coords);
        const auto original_selection = [self localCharsSelection];
        for( auto event = _event; event && event.type != NSLeftMouseUp;
            event = [self.window nextEventMatchingMask:event_mask] ) {
            const auto curr_view_coords = [self convertPoint:event.locationInWindow fromView:nil];
            const auto curr_ind = m_Layout->CharOffsetFromSnippetHit(curr_view_coords);
            const auto selection = HexModeLayout::MergeSelection(original_selection, 
                                                                 modifying_existing_selection, 
                                                                 first_ind, 
                                                                 curr_ind);
            if( selection.first != selection.second ) {                
                const auto global = CFRangeMake(m_WorkingSet->ToGlobalByteOffset(selection.first),
                                                m_WorkingSet->ToGlobalByteOffset(selection.second) -
                                                m_WorkingSet->ToGlobalByteOffset(selection.first));
                [self.delegate hexModeView:self setSelection:global];
            }
            else
                [self.delegate hexModeView:self setSelection:CFRangeMake(-1,0)];
        }   
    }
}

- (CFRange)localBytesSelection
{
    if( self.delegate == nil )
        return CFRangeMake(kCFNotFound, 0);    
    const auto global_byte_selection = [self.delegate hexModeViewProvideSelection:self];
    const auto &ws = m_Frame->WorkingSet();
    return ws.ToLocalBytesRange(global_byte_selection);
}

- (CFRange)localCharsSelection
{
    const auto bytes = [self localBytesSelection];
    if( CFRangeEmpty(bytes) )
        return {-1, 0};
    
    const auto first = m_WorkingSet->ToLocalCharIndex( (int)bytes.location );
    const auto last = m_WorkingSet->ToLocalCharIndex( (int)CFRangeMax(bytes) );
    return CFRangeMake(first, last-first);
}

- (void) selectionHasChanged
{
    [self setNeedsDisplay:true];
}

- (void) themeHasChanged
{
    m_FontInfo = FontGeometryInfo{ (__bridge CTFontRef)m_Theme->Font() };
    const auto scroll_offset = m_Layout->GetOffset();    
    const auto old_frame = m_Frame;
    m_Frame = [self buildFrame];
    m_Layout->SetFrame(m_Frame);
    auto new_offset = HexModeLayout::FindEqualVerticalOffsetForRebuiltFrame(*old_frame,
                                                                            scroll_offset.row,
                                                                            *m_Frame);
    m_Layout->SetOffset({new_offset, scroll_offset.smooth});
    [self scrollPositionDidChange];
    [self setNeedsDisplay:true];
}

@end

static std::shared_ptr<const TextModeWorkingSet> BuildWorkingSetForBackendState
    (const DataBackend& _backend)
{
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = (const char16_t*)_backend.UniChars();
    source.mapping_to_byte_offsets = (const int*)_backend.UniCharToByteIndeces();
    source.characters_number = _backend.UniCharsSize();
    source.bytes_offset = (long)_backend.FilePos();
    source.bytes_length = (int)_backend.RawSize();
    return std::make_shared<TextModeWorkingSet>(source);
}

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
