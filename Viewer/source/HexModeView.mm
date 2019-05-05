#include "HexModeView.h"
//#include "HexModeContentView.h"
#include "HexModeFrame.h"
#include "HexModeLayout.h"

#include <Habanero/mach_time.h>

#include <iostream>
#include <cmath>


using namespace nc;
using namespace nc::viewer;
using nc::utility::FontGeometryInfo;

static const auto g_TopInset = 4.;
static const auto g_LeftInset = 4.;
static const auto g_RightInset = 4.;

static std::shared_ptr<const TextModeWorkingSet> MakeEmptyWorkingSet();
static std::shared_ptr<const TextModeWorkingSet>
    BuildWorkingSetForBackendState(const BigFileViewDataBackend& _backend);

@implementation NCViewerHexModeView
{
    const BigFileViewDataBackend *m_Backend;
    const Theme *m_Theme;
    NSScrollView *m_ScrollView;
//    NCViewerHexModeContentView *m_ContentView;
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::shared_ptr<const HexModeFrame> m_Frame;
    FontGeometryInfo m_FontInfo;
    std::unique_ptr<HexModeLayout> m_Layout;
//    long m_RowOffset;
//    double m_SmoothOffset;
    NSScroller *m_VerticalScroller;
}

- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(const BigFileViewDataBackend&)_backend
                        theme:(const nc::viewer::Theme&)_theme
{
    if( self = [super initWithFrame:_frame] ) {
        m_Backend = &_backend;
        m_Theme = &_theme;
        m_FontInfo = FontGeometryInfo{ (__bridge CTFontRef)m_Theme->Font() };
        m_WorkingSet = MakeEmptyWorkingSet();
        m_Frame = [self buildFrame];
        
//        m_RowOffset = 0;
//        m_SmoothOffset = 0.;
        self.translatesAutoresizingMaskIntoConstraints = false;
        
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

        
//        m_ScrollView = [[NSScrollView alloc] initWithFrame:_frame];
//        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
//        m_ScrollView.hasVerticalScroller = true;
//        m_ScrollView.contentView.postsBoundsChangedNotifications = true;
//
//        m_ContentView = [[NCViewerHexModeContentView alloc] initWithFrame:_frame];
//
//        m_ScrollView.documentView = m_ContentView;
        
//
//        [self addSubview:m_ScrollView];
//        auto scroll_view = m_ScrollView;
//        NSDictionary *views = NSDictionaryOfVariableBindings(scroll_view);
//        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
//                              @"|-(==0)-[scroll_view]-(==0)-|" options:0 metrics:nil views:views]];
//        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
//                              @"V:|-(==0)-[scroll_view]-(==0)-|" options:0 metrics:nil views:views]];
//        [self addConstraint:[NSLayoutConstraint constraintWithItem:m_ContentView
//                                                         attribute:NSLayoutAttributeWidth
//                                                         relatedBy:NSLayoutRelationEqual
//                                                            toItem:m_ScrollView.contentView
//                                                         attribute:NSLayoutAttributeWidth
//                                                        multiplier:1.0
//                                                          constant:0]];
//
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(contentWasScrolled:)
//                                                     name:NSViewBoundsDidChangeNotification
//                                                   object:m_ScrollView.contentView];
//
//        customView.height >= clipView.height (prio:1000)
//        customView.width >= clipView.width (prio:1000)
        
//        m_View = view;

//        m_ScrollView
        [self backendContentHasChanged];
    }
    return self;
}

- (BOOL)isFlipped
{
    return true;
}

- (void)backendContentHasChanged
{
//    m_ContentView.fileSize = (long)m_Backend->FileSize();
    [self rebuildWorkingSetAndFrame];
}

- (void)rebuildWorkingSetAndFrame
{
    m_WorkingSet = BuildWorkingSetForBackendState(*m_Backend);
    
    MachTimeBenchmark mtb;
    m_Frame = [self buildFrame];
    mtb.ResetMilli();
    
    m_Layout->SetFrame(m_Frame);
    [self setNeedsDisplay:true];
//    [self syncVerticalScrollerPosition];
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

    return std::make_shared<HexModeFrame>(source);
}

//- (bool)haveContentToDraw
//{
//    if( m_Frame == nullptr )
//        return true;
//
//    const auto view_top_y = m_ScrollView.contentView.bounds.origin.y;
//    const auto view_top_index = long(view_top_y / m_Frame->FontInfo().LineHeight());
//
//    const long global_index_of_first_row =
//    (long(m_Frame->RowAtIndex(0).BytesStart()) + m_Frame->WorkingSet().GlobalOffset()) /
//    m_Frame->BytesPerRow();
//    const long global_index_of_last_row = global_index_of_first_row + m_Frame->NumberOfRows();
//    if( view_top_index >= global_index_of_first_row &&
//       view_top_index < global_index_of_last_row ) {
//        return true;
//    }
//
////    const long index_start = global_row_index_start - global_index_of_first_row;
////    const long index_end = global_row_index_end - global_index_of_first_row;
//
//    return false;
//}

//- (void)contentWasScrolled:(id)sender
//{
////    int a = 10;
////    std::cout << "has content: " << [self haveContentToDraw] << std::endl;
//    if( [self haveContentToDraw] == false ) {
//        [self reloadData];
//    }
//}

//- (void)reloadData
//{
//    const auto view_top_y = m_ScrollView.contentView.bounds.origin.y;
//    const auto view_top_index = long(view_top_y / m_Frame->FontInfo().LineHeight());
//    const auto view_top_offset = view_top_index * m_Frame->BytesPerRow();
//    const auto new_offset = std::clamp(int64_t(view_top_offset -
//                                               m_Frame->WorkingSet().BytesLength() / 10),
//                                       (int64_t)0,
//                                       (int64_t)(m_Backend->FileSize() -
//                                                 m_Backend->RawSize()) );
//
////    const auto new_offset = std::max( view_top_offset, 0l );
//
////    const auto desired_window_offset = std::clamp(old_anchor_glob_offset -
////                                                  (int64_t)m_Backend->RawSize() +
////                                                  (int64_t)m_Backend->RawSize() / 4,
////                                                  (int64_t)0,
////                                                  (int64_t)(m_Backend->FileSize() -
////                                                            m_Backend->RawSize()) );
//
//    const auto rc = [self.delegate hexModeView:self
//            requestsSyncBackendWindowMovementAt:new_offset];
//    if( rc != VFSError::Ok ) {
//        std::cout << "failed to move the backend window: "
//        << VFSError::ToNSError(rc).description.UTF8String << std::endl;
//        return;
//    }
//
//    [self rebuildWorkingSetAndFrame];
//}

- (void)syncVerticalScrollerPosition
{
    const auto scroll_pos = m_Layout->CalcScrollerPosition();
    m_VerticalScroller.doubleValue = scroll_pos.position;
    m_VerticalScroller.knobProportion = scroll_pos.proportion;
}

- (void)onVerticalScroll:(id)_sender
{
    switch( m_VerticalScroller.hitPart ) {
//        case NSScrollerIncrementLine:
//            [self moveDown:_sender];
//            break;
//        case NSScrollerIncrementPage:
//            [self pageDown:_sender];
//            break;
//        case NSScrollerDecrementLine:
//            [self moveUp:_sender];
//            break;
//        case NSScrollerDecrementPage:
//            [self pageUp:_sender];
//            break;
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
    const auto origin = CGPointMake(g_LeftInset, g_TopInset);
    const auto offset = m_Layout->GetOffset();
    const auto vertical_shift = offset.row * m_FontInfo.LineHeight() + offset.smooth;
    return CGPointMake(origin.x, origin.y - vertical_shift);
}

- (void)drawRect:(NSRect)dirtyRect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
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
    
//    if( m_Frame == nullptr || m_Frame->Empty() )
//        return;
    
 
    // + smooth offset
//    const long global_row_index_start =
//        m_Layout->GetOffset().row +
//        (long)std::floor(dirtyRect.origin.y / m_Frame->FontInfo().LineHeight());
//    const long global_row_index_end = global_row_index_start +
//        (long)std::ceil(dirtyRect.size.height / m_Frame->FontInfo().LineHeight());
//
//    const long global_index_of_first_row =
//        (long(m_Frame->RowAtIndex(0).BytesStart()) + m_Frame->WorkingSet().GlobalOffset()) /
//        m_Frame->BytesPerRow();

//    - (CGPoint)textOrigin
//    {
//        const auto origin = CGPointMake(g_LeftInset, g_TopInset);
//        const auto vertical_shift = m_VerticalLineOffset * m_FontInfo.LineHeight() + m_PxOffset.y;
//        const auto horizontal_shift = m_HorizontalCharsOffset * m_FontInfo.PreciseMonospaceWidth() +
//        m_PxOffset.x;
//        return CGPointMake(origin.x - horizontal_shift, origin.y - vertical_shift);
//    }
    
//    const long index_start = global_row_index_start - global_index_of_first_row;
//    const long index_end = global_row_index_end - global_index_of_first_row;

//        const auto view_width = self.bounds.size.width;
    const auto origin = [self textOrigin];

    const auto lines_per_screen =
        (int)std::ceil( self.bounds.size.height / m_FontInfo.LineHeight() );
//
        // both lines_start and lines_end are _not_ clamped regarding real Frame data!
    const int lines_start = (int)std::floor( (0. - origin.y) / m_FontInfo.LineHeight() );
//
    // +1 to ensure that selection of a following line is also visible
    const int lines_end = lines_start + lines_per_screen + 1;
//
    auto line_pos = CGPointMake( origin.x, origin.y + lines_start * m_FontInfo.LineHeight() );
//
//        const auto selection = [self localSelection];
//        
//        for( int line_no = lines_start;
//            line_no < lines_end;
//            ++line_no, line_pos.y += m_FontInfo.LineHeight() ) {
    
    
//    const long index_start =
//        m_Layout->GetOffset().row +
//        (long)std::floor(dirtyRect.origin.y / m_Frame->FontInfo().LineHeight());
//
//
//    CGPoint line_origin = CGPointMake(0.,
////                                      global_row_index_start * m_Frame->FontInfo().LineHeight()
//                                      - m_Layout->GetOffset().smooth
//                                      );
    
    
//    std::cout << "line origin y: " << line_origin.y << std::endl;
    for( long index = lines_start;
        index < lines_end;
        ++index, line_pos.y += m_Frame->FontInfo().LineHeight() ) {
        if( index < 0 || index >= m_Frame->NumberOfRows() )
            continue;
        
        const auto text_origin = CGPointMake(line_pos.x,
                                             line_pos.y +
                                             m_Frame->FontInfo().LineHeight() -
                                             m_Frame->FontInfo().Descent() );
        
        auto &row = m_Frame->RowAtIndex(int(index));
        CGContextSetTextPosition( context, text_origin.x, text_origin.y );
        CTLineDraw(row.AddressLine(), context );
        
        CGContextSetTextPosition( context, text_origin.x + 100, text_origin.y );
        CTLineDraw(row.ColumnLine(0), context );

        if( row.ColumnsNumber() >= 2 ) {
            CGContextSetTextPosition( context, text_origin.x + 300, text_origin.y );
            CTLineDraw(row.ColumnLine(1), context );
        }

        CGContextSetTextPosition( context, text_origin.x + 500, text_origin.y );
        CTLineDraw(row.SnippetLine(), context );
        
    }
    
    
    
}

- (void)frameDidChange
{
    m_Layout->SetViewSize(self.frame.size);
    
//    [self syncVerticalScrollerPosition];
    [self scrollPositionDidChange];
    
//    if( [self shouldRebuilFrameForChangedFrame] ) {
//        const auto new_frame = [self buildLayout];
//        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame,
//                                                                      m_VerticalLineOffset,
//                                                                      *new_frame);
//        m_Frame = new_frame;
//        [self scrollPositionDidChange];
//    }
//    [self setNeedsDisplay:true];
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
    
    if( self.delegate ) {
        const auto bytes_position = m_Layout->CalcGlobalOffset();
//        ((m_VerticalLineOffset >= 0 && m_VerticalLineOffset < m_Frame->LinesNumber()) ?
//         m_Frame->Line(m_VerticalLineOffset).BytesStart() : 0)
//        + m_Frame->WorkingSet().GlobalOffset();
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

//- (bool) canScrollDown
//{
//    return
//    (m_Backend->FilePos() + m_Backend->RawSize() < m_Backend->FileSize()) ||
//    (m_VerticalLineOffset + self.numberOfLinesFittingInView < m_Frame->LinesNumber());
//}

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
        assert( self.delegate );
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

- (void)scrollWheelVertical:(double)_delta_y
{
    const auto delta_y = _delta_y;
    if( delta_y > 0 ) { // going up
        double smooth_offset = m_Layout->GetOffset().smooth;
        if( [self canScrollUp] ) {
            [self setNeedsDisplay:true];
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
            [self setNeedsDisplay:true];
        }
        m_Layout->SetOffset({m_Layout->GetOffset().row, smooth_offset});
    }
//    if( delta_y < 0 ) { // going down
//        if( [self canScrollDown] ) {
//            [self setNeedsDisplay:true];
//            auto px_offset = m_PxOffset.y - delta_y;
//            m_PxOffset.y = 0;
//            while( px_offset >= m_FontInfo.LineHeight() ) {
//                const auto did_move = [self doMoveDownByOneLine];
//                if( did_move == false )
//                    break;
//                px_offset -= m_FontInfo.LineHeight();
//            }
//            m_PxOffset.y = std::clamp( px_offset, 0., m_FontInfo.LineHeight() );
//        }
//        else {
//            m_PxOffset.y = std::clamp(m_PxOffset.y - delta_y, -m_FontInfo.LineHeight(), 0.);
//            [self setNeedsDisplay:true];
//        }
//    }
}

- (void)scrollWheel:(NSEvent *)_event
{
    const auto delta_y = _event.hasPreciseScrollingDeltas ?
    _event.scrollingDeltaY :
    _event.scrollingDeltaY * m_FontInfo.LineHeight();
    [self scrollWheelVertical:delta_y];
    
//    const auto delta_x = _event.hasPreciseScrollingDeltas ?
//    _event.scrollingDeltaX :
//    _event.scrollingDeltaX * m_FontInfo.MonospaceWidth();
//    [self scrollWheelHorizontal:delta_x];
    
//    assert( std::abs(m_PxOffset.y) <= m_FontInfo.LineHeight() );
    [self scrollPositionDidChange];
}


@end


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
