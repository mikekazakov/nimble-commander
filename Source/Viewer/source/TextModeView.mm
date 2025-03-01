// Copyright (C) 2019-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextModeView.h"
#include "TextProcessing.h"
#include "TextModeIndexedTextLine.h"
#include "TextModeWorkingSet.h"
#include "TextModeWorkingSetHighlighting.h"
#include "TextModeFrame.h"
#include "Highlighting/SettingsStorage.h"

#include <cmath>
#include <iostream>
#include <algorithm>

using namespace nc;
using namespace nc::viewer;
using nc::utility::FontGeometryInfo;

static const auto g_TabSpaces = 4;
static const auto g_WrappingWidth = 10000.;
static const auto g_TopInset = 4.;
static const auto g_LeftInset = 4.;
static const auto g_RightInset = 4.;
static const auto g_SyncHighlightingThreshold = std::chrono::milliseconds{16};

namespace {
struct ScrollPosition {
    double position = 0.;
    double proportion = 0.;
};
} // namespace

static std::shared_ptr<const TextModeWorkingSet> MakeEmptyWorkingSet();

static std::shared_ptr<const TextModeWorkingSet> BuildWorkingSetForBackendState(const DataBackend &_backend);

static int FindEqualVerticalOffsetForRebuiltFrame(const TextModeFrame &old_frame,
                                                  int old_vertical_offset,
                                                  const TextModeFrame &new_frame);

static ScrollPosition CalculateScrollPosition(const TextModeFrame &_frame,
                                              const DataBackend &_backend,
                                              NSSize _view_size,
                                              int _vertical_line_offset,
                                              double _vertical_px_offset);

static int64_t CalculateGlobalBytesOffsetFromScrollPosition(const TextModeFrame &_frame,
                                                            const DataBackend &_backend,
                                                            NSSize _view_size,
                                                            int _vertical_line_offset,
                                                            double _scroll_knob_position);

static std::optional<int> FindVerticalLineToScrollToBytesOffsetWithFrame(const TextModeFrame &_frame,
                                                                         const DataBackend &_backend,
                                                                         NSSize _view_size,
                                                                         int64_t _global_offset);

static double CalculateVerticalPxPositionFromScrollPosition(const TextModeFrame &_frame,
                                                            NSSize _view_size,
                                                            double _scroll_knob_position);

@implementation NCViewerTextModeView {
    std::shared_ptr<const DataBackend> m_Backend;
    const Theme *m_Theme;
    hl::SettingsStorage *m_HighlightingSettings;
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::shared_ptr<TextModeWorkingSetHighlighting> m_WorkingSetHighlighting;
    std::shared_ptr<const TextModeFrame> m_Frame;
    std::string m_Language;
    bool m_LineWrap;
    bool m_EnableSyntaxHighlighting;
    FontGeometryInfo m_FontInfo;

    int m_VerticalLineOffset;    // offset in lines number within existing text lines in Frame
    int m_HorizontalCharsOffset; // horizontal offset/scroll in monowidth chars
    CGPoint m_PxOffset;          // smooth offset in pixels

    NSScroller *m_VerticalScroller;
}

@synthesize delegate;

- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(std::shared_ptr<const DataBackend>)_backend
                        theme:(const nc::viewer::Theme &)_theme
         highlightingSettings:(nc::viewer::hl::SettingsStorage &)_hl_settings
           enableHighlighting:(bool)_highlighting_enabled
{
    self = [super initWithFrame:_frame];
    if( self ) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        self.clipsToBounds = true;
        m_Backend = _backend;
        m_Theme = &_theme;
        m_HighlightingSettings = &_hl_settings;
        m_WorkingSet = MakeEmptyWorkingSet();
        m_LineWrap = true;
        m_FontInfo = FontGeometryInfo{(__bridge CTFontRef)m_Theme->Font()};
        m_VerticalLineOffset = 0;
        m_HorizontalCharsOffset = 0;
        m_PxOffset = CGPointMake(0., 0.);
        m_EnableSyntaxHighlighting = _highlighting_enabled;

        m_VerticalScroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, 15, 100)];
        m_VerticalScroller.enabled = true;
        m_VerticalScroller.target = self;
        m_VerticalScroller.action = @selector(onVerticalScroll:);
        m_VerticalScroller.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_VerticalScroller];

        NSDictionary *views = NSDictionaryOfVariableBindings(m_VerticalScroller);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_VerticalScroller(15)]-(0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_VerticalScroller]-(0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];

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

- (BOOL)acceptsFirstResponder
{
    return true;
}

- (const nc::viewer::TextModeWorkingSet &)workingSet
{
    assert(m_WorkingSet);
    return *m_WorkingSet;
}

- (const nc::viewer::TextModeFrame &)textFrame
{
    assert(m_Frame);
    return *m_Frame;
}

- (void)backendContentHasChanged
{
    [self rebuildWorkingSetAndHighlightingAndFrame];
}

- (void)attachToNewBackend:(std::shared_ptr<const nc::viewer::DataBackend>)_backend
{
    m_Backend = _backend;
    [self rebuildWorkingSetAndHighlightingAndFrame];
}

- (void)rebuildWorkingSetAndHighlightingAndFrame
{
    m_WorkingSet = BuildWorkingSetForBackendState(*m_Backend);
    [self rebuildHighlightingAndFrame];
}

- (void)rebuildHighlightingAndFrame
{
    m_WorkingSetHighlighting.reset();
    if( m_EnableSyntaxHighlighting && !m_Language.empty() ) {
        if( const std::shared_ptr<const std::string> settings = m_HighlightingSettings->Settings(m_Language) ) {
            m_WorkingSetHighlighting = std::make_shared<TextModeWorkingSetHighlighting>(m_WorkingSet, settings);
            __weak NCViewerTextModeView *weak_self = self;
            m_WorkingSetHighlighting->Highlight(g_SyncHighlightingThreshold,
                                                [weak_self](std::shared_ptr<const TextModeWorkingSetHighlighting> _hl) {
                                                    NCViewerTextModeView *const strong_self = weak_self;
                                                    if( !strong_self || _hl != strong_self->m_WorkingSetHighlighting )
                                                        return;
                                                    [strong_self highlightingHasChanged];
                                                });
        }
    }

    m_Frame = [self buildLayout];
    [self setNeedsDisplay:true];
    [self scrollPositionDidChange];
}

- (NSSize)contentsSize
{
    auto width = self.bounds.size.width - g_LeftInset - g_RightInset - m_VerticalScroller.bounds.size.width;
    auto height = self.bounds.size.height;

    return NSMakeSize(width, height);
}

- (double)wrappingWidth
{
    return m_LineWrap ? self.contentsSize.width : g_WrappingWidth;
}

- (std::shared_ptr<const TextModeFrame>)buildLayout
{
    const auto wrapping_width = [self wrappingWidth];
    using S = hl::Style;
    TextModeFrame::Source source;
    source.wrapping_width = wrapping_width;
    source.font = (__bridge CTFontRef)m_Theme->Font();
    source.font_info = m_FontInfo;
    source.foreground_colors[std::to_underlying(S::Default)] = m_Theme->TextColor().CGColor;
    source.foreground_colors[std::to_underlying(S::Comment)] = m_Theme->TextSyntaxCommentColor().CGColor;
    source.foreground_colors[std::to_underlying(S::Preprocessor)] = m_Theme->TextSyntaxPreprocessorColor().CGColor;
    source.foreground_colors[std::to_underlying(S::Keyword)] = m_Theme->TextSyntaxKeywordColor().CGColor;
    source.foreground_colors[std::to_underlying(S::Operator)] = m_Theme->TextSyntaxOperatorColor().CGColor;
    source.foreground_colors[std::to_underlying(S::Identifier)] = m_Theme->TextSyntaxIdentifierColor().CGColor;
    source.foreground_colors[std::to_underlying(S::Number)] = m_Theme->TextSyntaxNumberColor().CGColor;
    source.foreground_colors[std::to_underlying(S::String)] = m_Theme->TextSyntaxStringColor().CGColor;
    source.tab_spaces = g_TabSpaces;
    source.working_set = m_WorkingSet;
    source.working_set_highlighting = m_WorkingSetHighlighting;
    return std::make_shared<TextModeFrame>(source);
}

/**
 * Returns local view coordinates of the left-top corner of text.
 * Does move on both vertical and horizontal movement.
 */
- (CGPoint)textOrigin
{
    const auto origin = CGPointMake(g_LeftInset, g_TopInset);
    const auto vertical_shift = (m_VerticalLineOffset * m_FontInfo.LineHeight()) + m_PxOffset.y;
    const auto horizontal_shift = (m_HorizontalCharsOffset * m_FontInfo.PreciseMonospaceWidth()) + m_PxOffset.x;
    return CGPointMake(origin.x - horizontal_shift, origin.y - vertical_shift);
}

/**
 * Returns a number of lines which could be fitted into the view.
 * This is a floor estimation, i.e. number of fully fitting lines.
 */
- (int)numberOfLinesFittingInView
{
    const auto vertical_lines = static_cast<int>(std::floor(self.contentsSize.height / m_FontInfo.LineHeight()));
    return vertical_lines;
}

- (CFRange)localSelection
{
    if( self.delegate == nil )
        return CFRangeMake(kCFNotFound, 0);

    const auto global_byte_selection = [self.delegate textModeViewProvideSelection:self];
    const auto &ws = m_Frame->WorkingSet();
    const auto local_byte_selection = ws.ToLocalBytesRange(global_byte_selection);
    const auto head = ws.ToLocalCharIndex(int(local_byte_selection.location));
    if( head < 0 )
        return CFRangeMake(kCFNotFound, 0);
    const auto tail = ws.ToLocalCharIndex(int(local_byte_selection.location + local_byte_selection.length));
    if( tail < 0 )
        return CFRangeMake(kCFNotFound, 0);

    return CFRangeMake(head, tail - head);
}

- (void)drawRect:(NSRect)_dirty_rect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;

    CGContextSetFillColorWithColor(context, m_Theme->ViewerBackgroundColor().CGColor);
    CGContextFillRect(context, NSRectToCGRect(self.bounds));
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

    const auto view_width = self.bounds.size.width;
    const auto origin = [self textOrigin];

    const auto lines_per_screen = static_cast<int>(std::ceil(self.bounds.size.height / m_FontInfo.LineHeight()));

    // both lines_start and lines_end are _not_ clamped regarding real Frame data!
    const int lines_start = static_cast<int>(std::floor((0. - origin.y) / m_FontInfo.LineHeight()));

    // +1 to ensure that selection of a following line is also visible
    const int lines_end = lines_start + lines_per_screen + 1;

    auto line_pos = CGPointMake(origin.x, origin.y + (lines_start * m_FontInfo.LineHeight()));

    const auto selection = [self localSelection];

    for( int line_no = lines_start; line_no < lines_end; ++line_no, line_pos.y += m_FontInfo.LineHeight() ) {
        if( line_no < 0 || line_no >= m_Frame->LinesNumber() )
            continue;
        auto &line = m_Frame->Line(line_no);
        const auto text_origin = CGPointMake(line_pos.x, line_pos.y + m_FontInfo.LineHeight() - m_FontInfo.Descent());

        // draw the selection background
        if( selection.location >= 0 ) {
            const auto selection_end = selection.location + selection.length;
            double x1 = 0;
            double x2 = -1;
            if( line.UniCharsStart() <= selection.location && line.UniCharsEnd() > selection.location ) {
                x1 = line_pos.x + CTLineGetOffsetForStringIndex(line.Line(), selection.location, nullptr);
                x2 = ((selection_end <= line.UniCharsEnd())
                          ? line_pos.x + CTLineGetOffsetForStringIndex(line.Line(), selection_end, nullptr)
                          : view_width);
            }
            else if( selection_end > line.UniCharsStart() && selection_end <= line.UniCharsEnd() ) {
                x1 = line_pos.x;
                x2 = line_pos.x +
                     CTLineGetOffsetForStringIndex(line.Line(), selection.location + selection.length, nullptr);
            }
            else if( selection.location < line.UniCharsStart() && selection_end > line.UniCharsEnd() ) {
                x1 = line_pos.x;
                x2 = view_width;
            }

            if( x2 > x1 ) {
                CGContextSaveGState(context);
                CGContextSetShouldAntialias(context, false);
                CGContextSetFillColorWithColor(context, m_Theme->ViewerSelectionColor().CGColor);
                CGContextFillRect(context, CGRectMake(x1, line_pos.y, x2 - x1, m_FontInfo.LineHeight()));
                CGContextRestoreGState(context);
            }
        }

        // draw the text line itself
        CGContextSetTextPosition(context, text_origin.x, text_origin.y);
        CTLineDraw(line.Line(), context);
    }
}

- (void)drawFocusRingMask
{
    NSRectFill(self.focusRingMaskBounds);
}

- (NSRect)focusRingMaskBounds
{
    return self.bounds;
}

- (bool)doMoveUpByOneLine
{
    if( m_VerticalLineOffset > 0 ) {
        m_VerticalLineOffset--;
        [self setNeedsDisplay:true];
        return true;
    }
    else if( [self canMoveFileWindowUp] ) {
        assert(self.delegate);
        const auto old_frame = m_Frame;
        const auto old_anchor_line_index = std::clamp(m_VerticalLineOffset, 0, old_frame->LinesNumber() - 1);
        const auto old_anchor_glob_offset = static_cast<long>(old_frame->Line(old_anchor_line_index).BytesStart()) +
                                            old_frame->WorkingSet().GlobalOffset();
        const auto desired_window_offset =
            std::clamp(old_anchor_glob_offset - static_cast<int64_t>(m_Backend->RawSize()) +
                           (static_cast<int64_t>(m_Backend->RawSize()) / 4),
                       static_cast<int64_t>(0),
                       static_cast<int64_t>(m_Backend->FileSize() - m_Backend->RawSize()));

        const auto rc = [self.delegate textModeView:self requestsSyncBackendWindowMovementAt:desired_window_offset];
        if( !rc )
            return false;

        [self rebuildWorkingSetAndHighlightingAndFrame];

        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*old_frame, m_VerticalLineOffset, *m_Frame);
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
    if( m_VerticalLineOffset + self.numberOfLinesFittingInView < m_Frame->LinesNumber() ) {
        m_VerticalLineOffset++;
        [self setNeedsDisplay:true];
        return true;
    }
    else if( [self canMoveFileWindowDown] ) {
        assert(self.delegate);
        const auto old_frame = m_Frame;
        const auto old_anchor_line_index = std::clamp(m_VerticalLineOffset, 0, old_frame->LinesNumber() - 1);
        const auto old_anchor_glob_offset = static_cast<long>(old_frame->Line(old_anchor_line_index).BytesStart()) +
                                            old_frame->WorkingSet().GlobalOffset();
        const auto desired_window_offset =
            std::clamp(old_anchor_glob_offset - (static_cast<int64_t>(m_Backend->RawSize()) / 4),
                       static_cast<int64_t>(0),
                       static_cast<int64_t>(m_Backend->FileSize() - m_Backend->RawSize()));
        if( desired_window_offset <= static_cast<int64_t>(m_Backend->FilePos()) )
            return false; // singular situation. don't handle for now.

        const auto rc = [self.delegate textModeView:self requestsSyncBackendWindowMovementAt:desired_window_offset];
        if( !rc )
            return false;

        [self rebuildWorkingSetAndHighlightingAndFrame];

        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*old_frame, m_VerticalLineOffset, *m_Frame);
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

- (void)moveUp:(id) [[maybe_unused]] _sender
{
    [self doMoveUpByOneLine];
    [self scrollPositionDidChange];
}

- (void)moveDown:(id) [[maybe_unused]] _sender
{
    [self doMoveDownByOneLine];
    [self scrollPositionDidChange];
}

- (void)moveLeft:(id) [[maybe_unused]] _sender
{
    [self scrollWheelHorizontal:m_FontInfo.PreciseMonospaceWidth()];
}

- (void)moveRight:(id) [[maybe_unused]] _sender
{
    [self scrollWheelHorizontal:-m_FontInfo.PreciseMonospaceWidth()];
}

- (void)pageDown:(nullable id) [[maybe_unused]] _sender
{
    int lines_to_scroll = [self numberOfLinesFittingInView];
    while( lines_to_scroll-- > 0 )
        [self doMoveDownByOneLine];
    [self scrollPositionDidChange];
}

- (void)pageUp:(nullable id) [[maybe_unused]] _sender
{
    int lines_to_scroll = [self numberOfLinesFittingInView];
    while( lines_to_scroll-- > 0 )
        [self doMoveUpByOneLine];
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

/**
 * Returns true if either the line offset is greater than zero or
 * the backend window position is not at the beginning of the file.
 */
- (bool)canScrollUp
{
    return m_VerticalLineOffset > 0 || m_Backend->FilePos() > 0;
}

- (bool)isAtTheBeginning
{
    // Determines if the view shows the first line in the file, i.e. both its file window is at the
    // beginning of the file and the first portion of that window in shown.
    return ![self canScrollUp];
}

- (bool)canScrollDown
{
    return (m_Backend->FilePos() + m_Backend->RawSize() < m_Backend->FileSize()) ||
           (m_VerticalLineOffset + self.numberOfLinesFittingInView < m_Frame->LinesNumber());
}

- (bool)isAtTheEnd
{
    // Determines if the view shows the last line in the file, i.e. both its file window is at the
    // end of the file and the last portion of that window in shown.
    return ![self canScrollDown];
}

- (void)scrollWheelVertical:(double)_delta_y
{
    const auto delta_y = _delta_y;
    if( delta_y > 0 ) { // going up
        if( [self canScrollUp] ) {
            [self setNeedsDisplay:true];
            auto px_offset = m_PxOffset.y - delta_y;
            m_PxOffset.y = 0;
            while( px_offset <= -m_FontInfo.LineHeight() ) {
                const auto did_move = [self doMoveUpByOneLine];
                if( !did_move )
                    break;
                px_offset += m_FontInfo.LineHeight();
            }
            m_PxOffset.y = std::clamp(px_offset, -m_FontInfo.LineHeight(), 0.);
        }
        else {
            m_PxOffset.y = std::max(m_PxOffset.y - delta_y, 0.0);
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
                if( !did_move )
                    break;
                px_offset -= m_FontInfo.LineHeight();
            }
            m_PxOffset.y = std::clamp(px_offset, 0., m_FontInfo.LineHeight());
        }
        else {
            m_PxOffset.y = std::clamp(m_PxOffset.y - delta_y, -m_FontInfo.LineHeight(), 0.);
            [self setNeedsDisplay:true];
        }
    }
}

- (void)scrollWheelHorizontal:(double)_delta_x
{
    const auto delta_x = _delta_x;
    if( delta_x > 0 ) { // going right
        auto px_offset = m_PxOffset.x - delta_x;
        m_PxOffset.x = 0;
        while( px_offset <= -m_FontInfo.PreciseMonospaceWidth() ) {
            m_HorizontalCharsOffset -= 1;
            px_offset += m_FontInfo.PreciseMonospaceWidth();
        }
        if( m_HorizontalCharsOffset * m_FontInfo.PreciseMonospaceWidth() + px_offset < 0. ) {
            // left-bound clamp
            m_HorizontalCharsOffset = 0;
            px_offset = 0.;
        }
        m_PxOffset.x = px_offset;

        [self setNeedsDisplay:true];
    }
    if( delta_x < 0 ) { // going left
        auto px_offset = m_PxOffset.x - delta_x;
        m_PxOffset.x = 0;
        while( px_offset >= m_FontInfo.PreciseMonospaceWidth() ) {
            m_HorizontalCharsOffset += 1;
            px_offset -= m_FontInfo.PreciseMonospaceWidth();
        }
        const auto gap = m_Frame->Bounds().width - self.contentsSize.width;
        if( gap <= 0 ) {
            m_HorizontalCharsOffset = 0;
            px_offset = 0.;
        }
        else if( m_HorizontalCharsOffset * m_FontInfo.PreciseMonospaceWidth() + px_offset > gap ) {
            // right-bound clamp
            m_HorizontalCharsOffset = static_cast<int>(std::floor(gap / m_FontInfo.PreciseMonospaceWidth()));
            px_offset = std::fmod(gap, m_FontInfo.PreciseMonospaceWidth());
        }
        m_PxOffset.x = px_offset;
        [self setNeedsDisplay:true];
    }
}

- (void)scrollWheel:(NSEvent *)_event
{
    const auto delta_y =
        _event.hasPreciseScrollingDeltas ? _event.scrollingDeltaY : _event.scrollingDeltaY * m_FontInfo.LineHeight();
    const auto delta_x = _event.hasPreciseScrollingDeltas ? _event.scrollingDeltaX
                                                          : _event.scrollingDeltaX * m_FontInfo.MonospaceWidth();

    // Emulate 'predominant axis scrolling' by picking only the greatest magnitude.
    // The implementation in NSScrollView is probably much more complex, but it's unclear
    // how it works under the hood.
    if( std::abs(delta_y) > std::abs(delta_x) ) {
        [self scrollWheelVertical:delta_y];
    }
    else {
        [self scrollWheelHorizontal:delta_x];
    }
    assert(std::abs(m_PxOffset.y) <= m_FontInfo.LineHeight());
    [self scrollPositionDidChange];
}

- (void)syncVerticalScrollerPosition
{
    const auto scroll_pos =
        CalculateScrollPosition(*m_Frame, *m_Backend, self.contentsSize, m_VerticalLineOffset, m_PxOffset.y);
    m_VerticalScroller.doubleValue = scroll_pos.position;
    m_VerticalScroller.knobProportion = scroll_pos.proportion;
}

- (void)onVerticalScroll:(id)_sender
{
    switch( m_VerticalScroller.hitPart ) {
        case NSScrollerIncrementPage:
            [self pageDown:_sender];
            break;
        case NSScrollerDecrementPage:
            [self pageUp:_sender];
            break;
        case NSScrollerKnob: {
            if( m_Backend->IsFullCoverage() ) {
                const auto offset = CalculateVerticalPxPositionFromScrollPosition(
                    *m_Frame, self.contentsSize, m_VerticalScroller.doubleValue);
                [self scrollToVerticalPxPosition:offset];
            }
            else {
                const auto offset = CalculateGlobalBytesOffsetFromScrollPosition(
                    *m_Frame, *m_Backend, self.contentsSize, m_VerticalLineOffset, m_VerticalScroller.doubleValue);
                [self scrollToGlobalBytesOffset:offset];
            }
            break;
        }
        default:
            break;
    }
}

- (bool)scrollToVerticalPxPosition:(double)_position
{
    m_VerticalLineOffset = static_cast<int>(std::floor(_position / m_FontInfo.LineHeight()));
    m_PxOffset.y = std::fmod(_position, m_FontInfo.LineHeight());
    [self setNeedsDisplay:true];
    [self scrollPositionDidChange];
    return true;
}

- (bool)scrollToGlobalBytesOffset:(int64_t)_offset
{
    auto probe_instant =
        FindVerticalLineToScrollToBytesOffsetWithFrame(*m_Frame, *m_Backend, self.contentsSize, _offset);
    if( probe_instant != std::nullopt ) {
        // great, can satisfy the request instantly
        m_VerticalLineOffset = *probe_instant;
        m_PxOffset.y = 0.;
        [self setNeedsDisplay:true];
        [self scrollPositionDidChange];
        return true;
    }
    else {
        // nope, we need to perform I/O to move the file window
        if( !self.delegate )
            return false;

        const auto desired_wnd_pos =
            std::clamp(_offset - (static_cast<int64_t>(m_Backend->RawSize()) / 2),
                       static_cast<int64_t>(0),
                       static_cast<int64_t>(m_Backend->FileSize()) - static_cast<int64_t>(m_Backend->RawSize()));

        const auto rc = [self.delegate textModeView:self requestsSyncBackendWindowMovementAt:desired_wnd_pos];
        if( !rc )
            return false;

        [self rebuildWorkingSetAndHighlightingAndFrame];

        auto second_probe =
            FindVerticalLineToScrollToBytesOffsetWithFrame(*m_Frame, *m_Backend, self.contentsSize, _offset);
        if( second_probe != std::nullopt ) {
            m_VerticalLineOffset = *second_probe;
            m_PxOffset.y = 0.;
            [self setNeedsDisplay:true];
            [self scrollPositionDidChange];
            return true;
        }
        else {
            // this shouldn't happen... famous last words.
            return false;
        }
    }
}

- (void)frameDidChange
{
    if( [self shouldRebuilFrameForChangedFrame] ) {
        const auto new_frame = [self buildLayout];
        m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame, m_VerticalLineOffset, *new_frame);
        m_Frame = new_frame;
        [self scrollPositionDidChange];
    }
    [self setNeedsDisplay:true];
}

- (bool)shouldRebuilFrameForChangedFrame
{
    const auto current_wrapping_width = [self wrappingWidth];
    return m_Frame->WrappingWidth() != current_wrapping_width;
}

- (void)scrollPositionDidChange
{
    [self syncVerticalScrollerPosition];

    if( self.delegate ) {
        const auto bytes_position = ((m_VerticalLineOffset >= 0 && m_VerticalLineOffset < m_Frame->LinesNumber())
                                         ? m_Frame->Line(m_VerticalLineOffset).BytesStart()
                                         : 0) +
                                    m_Frame->WorkingSet().GlobalOffset();
        const auto scroll_position = m_VerticalScroller.doubleValue;

        [self.delegate textModeView:self
            didScrollAtGlobalBytePosition:bytes_position
                     withScrollerPosition:scroll_position];
    }
}

- (void)selectionHasChanged
{
    [self setNeedsDisplay:true];
}

- (void)lineWrappingHasChanged
{
    if( !self.delegate )
        return;

    m_LineWrap = [self.delegate textModeViewProvideLineWrapping:self];
    const auto new_frame = [self buildLayout];
    m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame, m_VerticalLineOffset, *new_frame);
    m_Frame = new_frame;
    [self scrollPositionDidChange];
    [self setNeedsDisplay:true];
}

- (CGPoint)viewCoordsToTextFrameCoords:(CGPoint)_view_coords
{
    const auto left_upper = [self textOrigin];
    return CGPointMake(_view_coords.x - left_upper.x, _view_coords.y - left_upper.y);
}

- (void)mouseDown:(NSEvent *)_event
{
    if( !self.delegate )
        return;

    if( _event.clickCount > 2 )
        [self handleSelectionWithTripleClick:_event];
    else if( _event.clickCount == 2 )
        [self handleSelectionWithDoubleClick:_event];
    else
        [self handleSelectionWithMouseDragging:_event];
}

static int base_index_with_existing_selection(const CFRange _existing_selection,
                                              const int _first_mouse_hit_index,
                                              const int _current_mouse_hit_index) noexcept
{
    if( _existing_selection.location < 0 )
        return _first_mouse_hit_index;

    if( _first_mouse_hit_index > _existing_selection.location &&
        _first_mouse_hit_index <= _existing_selection.location + _existing_selection.length ) {
        const auto attach_top = _first_mouse_hit_index - _existing_selection.location >
                                _existing_selection.location + _existing_selection.length - _first_mouse_hit_index;
        return attach_top
                   ? static_cast<int>(_existing_selection.location)
                   : static_cast<int>(_existing_selection.location) + static_cast<int>(_existing_selection.length);
    }
    else if( _first_mouse_hit_index < _existing_selection.location + _existing_selection.length &&
             _current_mouse_hit_index < _existing_selection.location + _existing_selection.length ) {
        return static_cast<int>(_existing_selection.location) + static_cast<int>(_existing_selection.length);
    }
    else if( _first_mouse_hit_index > _existing_selection.location &&
             _current_mouse_hit_index > _existing_selection.location )
        return static_cast<int>(_existing_selection.location);
    else
        return _first_mouse_hit_index;
}

- (void)handleSelectionWithMouseDragging:(NSEvent *)_event
{
    if( !self.delegate )
        return;

    const auto modifying_existing_selection = bool(_event.modifierFlags & NSEventModifierFlagShift);
    const auto first_down_view_coords = [self convertPoint:_event.locationInWindow fromView:nil];
    const auto first_down_frame_coords = [self viewCoordsToTextFrameCoords:first_down_view_coords];
    const auto first_ind = m_Frame->CharIndexForPosition(first_down_frame_coords);
    const auto original_selection = [self localSelection];
    const auto event_mask = NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp;
    for( auto event = _event; event && event.type != NSEventTypeLeftMouseUp;
         event = [self.window nextEventMatchingMask:event_mask] ) {

        const auto curr_view_coords = [self convertPoint:event.locationInWindow fromView:nil];
        const auto curr_frame_coords = [self viewCoordsToTextFrameCoords:curr_view_coords];
        const auto curr_ind = m_Frame->CharIndexForPosition(curr_frame_coords);

        const auto base_ind = modifying_existing_selection
                                  ? base_index_with_existing_selection(original_selection, first_ind, curr_ind)
                                  : first_ind;

        if( base_ind != curr_ind ) {
            const auto sel_start = std::min(base_ind, curr_ind);
            const auto sel_end = std::max(base_ind, curr_ind);
            const auto sel_start_byte = m_WorkingSet->ToGlobalByteOffset(sel_start);
            const auto sel_end_byte = m_WorkingSet->ToGlobalByteOffset(sel_end);
            [self.delegate textModeView:self setSelection:CFRangeMake(sel_start_byte, sel_end_byte - sel_start_byte)];
        }
        else
            [self.delegate textModeView:self setSelection:CFRangeMake(-1, 0)];
    }
}

- (void)handleSelectionWithDoubleClick:(NSEvent *)_event
{
    if( !self.delegate )
        return;

    const auto view_coords = [self convertPoint:_event.locationInWindow fromView:nil];
    const auto frame_coords = [self viewCoordsToTextFrameCoords:view_coords];
    const auto [sel_start, sel_end] = m_Frame->WordRangeForPosition(frame_coords);
    const auto sel_start_byte = m_WorkingSet->ToGlobalByteOffset(sel_start);
    const auto sel_end_byte = m_WorkingSet->ToGlobalByteOffset(sel_end);
    [self.delegate textModeView:self setSelection:CFRangeMake(sel_start_byte, sel_end_byte - sel_start_byte)];
}

- (void)handleSelectionWithTripleClick:(NSEvent *)_event
{
    if( !self.delegate )
        return;

    const auto view_coords = [self convertPoint:_event.locationInWindow fromView:nil];
    const auto frame_coords = [self viewCoordsToTextFrameCoords:view_coords];
    int line_no = m_Frame->LineIndexForPosition(frame_coords);
    if( line_no < 0 || line_no >= m_Frame->LinesNumber() )
        return;

    const auto &i = m_Frame->Line(line_no);
    const auto sel_start_byte = i.BytesStart();
    const auto sel_end_byte = i.BytesEnd();
    const auto global_selection = CFRangeMake(static_cast<long>(sel_start_byte) + m_Frame->WorkingSet().GlobalOffset(),
                                              static_cast<long>(sel_end_byte) - static_cast<long>(sel_start_byte));

    [self.delegate textModeView:self setSelection:global_selection];
}

- (void)themeHasChanged
{
    m_FontInfo = FontGeometryInfo{(__bridge CTFontRef)m_Theme->Font()};
    const auto new_frame = [self buildLayout];
    m_VerticalLineOffset = FindEqualVerticalOffsetForRebuiltFrame(*m_Frame, m_VerticalLineOffset, *new_frame);
    m_Frame = new_frame;
    [self scrollPositionDidChange];
    [self setNeedsDisplay:true];
}

- (void)highlightingHasChanged
{
    m_Frame = [self buildLayout];
    [self setNeedsDisplay:true];
}

- (void)syntaxHighlightingEnabled:(bool)_enabled
{
    if( m_EnableSyntaxHighlighting == _enabled ) {
        return;
    }
    m_EnableSyntaxHighlighting = _enabled;
    [self rebuildHighlightingAndFrame];
}

- (void)setHighlightingLanguage:(const std::string &)_language
{
    if( m_Language == _language ) {
        return; // nothing to do
    }

    m_Language = _language;
    [self rebuildHighlightingAndFrame];
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

static std::shared_ptr<const TextModeWorkingSet> BuildWorkingSetForBackendState(const DataBackend &_backend)
{
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = reinterpret_cast<const char16_t *>(_backend.UniChars());
    source.mapping_to_byte_offsets = reinterpret_cast<const int *>(_backend.UniCharToByteIndeces());
    source.characters_number = _backend.UniCharsSize();
    source.bytes_offset = static_cast<long>(_backend.FilePos());
    source.bytes_length = static_cast<int>(_backend.RawSize());
    return std::make_shared<TextModeWorkingSet>(source);
}

static int FindEqualVerticalOffsetForRebuiltFrame(const TextModeFrame &old_frame,
                                                  const int old_vertical_offset,
                                                  const TextModeFrame &new_frame)
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
            const auto closest = FindClosestLineIndex(
                new_frame.Lines().data(), new_frame.Lines().data() + new_frame.LinesNumber(), old_byte_offset);
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
            const auto &last_old_line = old_frame.Line(old_frame.LinesNumber() - 1);
            const auto old_byte_offset = last_old_line.BytesStart();
            const auto new_byte_offset = old_byte_offset + old_global_offset - new_global_offset;
            if( new_byte_offset < 0 || new_byte_offset > std::numeric_limits<int>::max() )
                return 0; // can't possibly satisfy
            const auto closest = FindClosestLineIndex(new_frame.Lines().data(),
                                                      new_frame.Lines().data() + new_frame.LinesNumber(),
                                                      static_cast<int>(new_byte_offset));
            return closest + delta_offset;
        }
        else {
            // general case - get the line and find the closest in the new frame
            const auto &old_line = old_frame.Line(old_vertical_offset);
            const auto old_byte_offset = old_line.BytesStart();
            const auto new_byte_offset = old_byte_offset + old_global_offset - new_global_offset;
            if( new_byte_offset < 0 || new_byte_offset > std::numeric_limits<int>::max() )
                return 0; // can't possibly satisfy
            const auto closest = FindClosestLineIndex(new_frame.Lines().data(),
                                                      new_frame.Lines().data() + new_frame.LinesNumber(),
                                                      static_cast<int>(new_byte_offset));
            return closest;
        }
    }
}

static ScrollPosition CalculateScrollPosition(const TextModeFrame &_frame,
                                              const DataBackend &_backend,
                                              const NSSize _view_size,
                                              const int _vertical_line_offset,
                                              const double _vertical_px_offset)
{
    const auto line_height = _frame.FontGeometryInfo().LineHeight();
    assert(line_height > 0.);

    ScrollPosition scroll_position;
    scroll_position.position = 0.;
    scroll_position.proportion = 1.;

    if( _backend.IsFullCoverage() ) {
        // calculate based on real pixel-wise position
        const auto full_height = _frame.LinesNumber() * line_height;
        if( full_height > _view_size.height ) {
            scroll_position.position =
                (_vertical_line_offset * line_height + _vertical_px_offset) / (full_height - _view_size.height);
            scroll_position.proportion = _view_size.height / full_height;
        }
        else { /* handled by the default initialization */
        }
    }
    else {
        // calculate based on byte-wise information
        if( _vertical_line_offset >= 0 && _vertical_line_offset < _frame.LinesNumber() ) {
            const auto first_line_index = _vertical_line_offset;
            const auto &first_line = _frame.Line(first_line_index);
            const auto lines_per_view = static_cast<int>(std::floor(_view_size.height / line_height));
            const auto last_line_index = std::min(first_line_index + lines_per_view - 1, _frame.LinesNumber() - 1);
            const auto &last_line = _frame.Line(last_line_index);
            const auto bytes_total = static_cast<int64_t>(_backend.FileSize());
            const auto bytes_on_screen = int64_t(last_line.BytesEnd() - first_line.BytesStart());
            const auto screen_start = first_line.BytesStart() + _frame.WorkingSet().GlobalOffset();
            scroll_position.position = double(screen_start) / double(bytes_total - bytes_on_screen);
            scroll_position.proportion = double(bytes_on_screen) / double(bytes_total);
        }
        else { /* handled by the default initialization */
        }
    }

    // Since this function doesn't fully trust the incoming parameters - this check in the end
    // to cause less confusion to AppKit in possible corner cases:
    scroll_position.position = std::clamp(scroll_position.position, 0., 1.);
    scroll_position.proportion = std::clamp(scroll_position.proportion, 0., 1.);
    return scroll_position;
}

static int64_t CalculateGlobalBytesOffsetFromScrollPosition(const TextModeFrame &_frame,
                                                            const DataBackend &_backend,
                                                            const NSSize _view_size,
                                                            int _vertical_line_offset,
                                                            const double _scroll_knob_position)
{
    const auto line_height = _frame.FontGeometryInfo().LineHeight();
    if( _vertical_line_offset >= 0 && _vertical_line_offset < _frame.LinesNumber() ) {
        const auto first_line_index = _vertical_line_offset;
        const auto &first_line = _frame.Line(first_line_index);
        const auto lines_per_view = static_cast<int>(std::floor(_view_size.height / line_height));
        const auto last_line_index = std::min(first_line_index + lines_per_view - 1, _frame.LinesNumber() - 1);
        const auto &last_line = _frame.Line(last_line_index);
        const auto bytes_total = static_cast<int64_t>(_backend.FileSize());
        const auto bytes_on_screen = static_cast<int64_t>(last_line.BytesEnd() - first_line.BytesStart());
        assert(bytes_total >= bytes_on_screen);
        return static_cast<int64_t>(_scroll_knob_position * double(bytes_total - bytes_on_screen));
    }
    else {
        return 0; // currently not handling in a reasonable manner.
    }
}

static std::optional<int> FindVerticalLineToScrollToBytesOffsetWithFrame(const TextModeFrame &_frame,
                                                                         const DataBackend &_backend,
                                                                         const NSSize _view_size,
                                                                         const int64_t _global_offset)
{
    if( _frame.Empty() ) {
        // edge-case - let's pretend that we found the line at the beginning
        return 0;
    }

    const auto line_height = _frame.FontGeometryInfo().LineHeight();
    const auto lines_per_view = static_cast<int>(std::floor(_view_size.height / line_height));
    const auto working_set_pos = _frame.WorkingSet().GlobalOffset();
    const auto working_set_len = static_cast<int64_t>(_frame.WorkingSet().BytesLength());
    const auto file_size = static_cast<int64_t>(_backend.FileSize());

    if( _global_offset >= working_set_pos && _global_offset < working_set_pos + working_set_len ) {
        // seems that we can satisfy this request immediately, without I/O
        const auto local_offset = static_cast<int>(_global_offset - working_set_pos);
        const auto first_line = _frame.Lines().data();
        const auto last_line = first_line + _frame.LinesNumber();
        const int closest = FindFloorClosestLineIndex(first_line, last_line, local_offset);
        if( closest + lines_per_view < _frame.LinesNumber() ) {
            // check that we will fill the whole screen after the scrolling
            return closest;
        }
        else if( working_set_pos + working_set_len == file_size ) {
            // special case if we're already at the bottom of the screen
            return std::clamp(_frame.LinesNumber() - lines_per_view, 0, _frame.LinesNumber() - 1);
        }
    }
    else if( _global_offset == file_size && working_set_pos + working_set_len == file_size ) {
        // special case if we're already at the bottom of the screen
        return std::clamp(_frame.LinesNumber() - lines_per_view, 0, _frame.LinesNumber() - 1);
    }
    return std::nullopt;
}

static double CalculateVerticalPxPositionFromScrollPosition(const TextModeFrame &_frame,
                                                            const NSSize _view_size,
                                                            const double _scroll_knob_position)
{
    const auto line_height = _frame.FontGeometryInfo().LineHeight();
    const auto full_height = _frame.LinesNumber() * line_height;
    if( full_height <= _view_size.height )
        return 0.;
    return _scroll_knob_position * (full_height - _view_size.height);
}
