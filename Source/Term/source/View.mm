// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "View.h"
#include <Utility/HexadecimalColor.h>
#include <Utility/FontCache.h>
#include <Utility/FontExtras.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/BlinkScheduler.h>
#include <Utility/NSEventModifierFlagsHolder.h>
#include <Base/algo.h>
#include "OrthodoxMonospace.h"
#include "Screen.h"
#include "Settings.h"
#include "CTCache.h"
#include "ColorMap.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <memory_resource>

using namespace nc;
using namespace nc::term;

using SelPoint = term::ScreenPoint;

[[clang::no_destroy]] static CTCacheRegistry
    g_CacheRegistry(ExtendedCharRegistry::SharedInstance()); // TODO: evil, refactor!

@implementation NCTermView {
    Screen *m_Screen;
    InputTranslator *m_InputTranslator;

    int m_LastScreenFullHeight;
    bool m_HasSelection;
    bool m_ReportsSizeByOccupiedContent;
    bool m_ShowCursor;
    bool m_IsFirstResponder;
    bool m_AllowCursorBlinking;
    bool m_CursorShouldBlink;
    bool m_HasVisibleBlinkingSpaces;
    TermViewCursor m_CursorType;
    SelPoint m_SelStart;
    SelPoint m_SelEnd;
    Interpreter::RequestedMouseEvents m_MouseEvents;

    FPSLimitedDrawer *m_FPS;
    NSSize m_IntrinsicSize;
    utility::BlinkScheduler m_BlinkScheduler;
    NSFont *m_Font;
    NSFont *m_BoldFont;
    NSFont *m_ItalicFont;
    NSFont *m_BoldItalicFont;
    std::shared_ptr<CTCache> m_FontCache;
    std::shared_ptr<CTCache> m_BoldFontCache;
    std::shared_ptr<CTCache> m_ItalicFontCache;
    std::shared_ptr<CTCache> m_BoldItalicFontCache;
    ColorMap m_Colors;
    std::shared_ptr<Settings> m_Settings;
    int m_SettingsNotificationTicket;
    SelPoint m_LastMouseCell;
}

@synthesize fpsDrawer = m_FPS;
@synthesize reportsSizeByOccupiedContent = m_ReportsSizeByOccupiedContent;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if( self ) {
        m_AllowCursorBlinking = true;
        m_IsFirstResponder = false;
        m_CursorShouldBlink = false;
        m_HasVisibleBlinkingSpaces = false;
        m_SettingsNotificationTicket = 0;
        m_CursorType = TermViewCursor::BlinkingBlock;
        m_MouseEvents = Interpreter::RequestedMouseEvents::None;
        m_LastMouseCell = {0, 0};

        __weak NCTermView *weak_self = self;
        m_BlinkScheduler = utility::BlinkScheduler([weak_self] {
            if( auto me = weak_self ) {
                //                std::cerr << "Blink! " << (__bridge void*)me << std::endl;
                [me->m_FPS invalidate];
            }
        });
        m_LastScreenFullHeight = 0;
        m_HasSelection = false;
        m_ReportsSizeByOccupiedContent = false;
        m_ShowCursor = true;
        m_FPS = [[FPSLimitedDrawer alloc] initWithView:self];
        m_FPS.fps = 60;
        m_IntrinsicSize = NSMakeSize(NSViewNoIntrinsicMetric, frame.size.height);
        self.settings = DefaultSettings::SharedDefaultSettings();
    }
    return self;
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    //    NSLog(@"%@ viewWillMoveToWindow: %@", self, _wnd);
    static const auto notify = NSNotificationCenter.defaultCenter;
    if( self.window ) {
        [notify removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
        [notify removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
    }
    if( _wnd ) {
        [notify addObserver:self
                   selector:@selector(viewStatusDidChange)
                       name:NSWindowDidBecomeKeyNotification
                     object:_wnd];
        [notify addObserver:self
                   selector:@selector(viewStatusDidChange)
                       name:NSWindowDidResignKeyNotification
                     object:_wnd];
    }
    else {
        m_IsFirstResponder = false;
        [self viewStatusDidChange];
    }
}

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    m_IsFirstResponder = true;
    [self viewStatusDidChange];
    return true;
}

- (BOOL)resignFirstResponder
{
    m_IsFirstResponder = false;
    [self viewStatusDidChange];
    return true;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)AttachToScreen:(term::Screen *)_scr
{
    m_Screen = _scr;
}

- (void)AttachToInputTranslator:(nc::term::InputTranslator *)_input_translator
{
    m_InputTranslator = _input_translator;
}

- (void)setAllowCursorBlinking:(bool)allowCursorBlinking
{
    m_AllowCursorBlinking = allowCursorBlinking;
    [self updateBlinkSheduling];
}

- (bool)allowCursorBlinking
{
    return m_AllowCursorBlinking;
}

- (void)setShowCursor:(bool)showCursor
{
    m_ShowCursor = showCursor;
}

- (bool)showCursor
{
    return m_ShowCursor;
}

- (double)charWidth
{
    return m_FontCache->Width();
}

- (double)charHeight
{
    return m_FontCache->Height();
}

- (void)keyDown:(NSEvent *)event
{
    NSString *const character = [event charactersIgnoringModifiers];
    if( [character length] == 1 )
        m_HasSelection = false;

    m_InputTranslator->ProcessKeyDown(event);
    [self scrollToBottom];
}

- (NSSize)intrinsicContentSize
{
    return m_IntrinsicSize;
}

- (int)fullScreenLinesHeight
{
    if( !m_ReportsSizeByOccupiedContent ) {
        return m_Screen->Height() + m_Screen->Buffer().BackScreenLines();
    }
    else {
        int onscreen = 0;
        if( auto occupied = m_Screen->Buffer().OccupiedOnScreenLines() )
            onscreen = occupied->second;
        if( m_Screen->CursorY() >= onscreen )
            onscreen = m_Screen->CursorY() + 1;
        return m_Screen->Buffer().BackScreenLines() + onscreen;
    }
}

- (void)adjustSizes:(bool)_mandatory
{
    const int full_lines_height = self.fullScreenLinesHeight;
    if( full_lines_height == m_LastScreenFullHeight && !_mandatory )
        return;

    m_LastScreenFullHeight = full_lines_height;
    const auto full_lines_height_px = full_lines_height * m_FontCache->Height();
    m_IntrinsicSize = NSMakeSize(NSViewNoIntrinsicMetric, full_lines_height_px);
    [self invalidateIntrinsicContentSize];
    [self.enclosingScrollView.contentView layoutSubtreeIfNeeded];
    [self scrollToBottom];
}

- (void)scrollToBottom
{
    auto scrollview = self.enclosingScrollView;
    auto clipview = scrollview.contentView;

    auto h1 = self.frame.size.height;
    auto h2 = scrollview.contentSize.height;
    if( h1 > h2 ) {
        auto p =
            NSMakePoint(0, self.superview.isFlipped ? (self.frame.size.height - scrollview.contentSize.height) : 0);
        [clipview scrollToPoint:p];
        [scrollview reflectScrolledClipView:clipview];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    // Drawing code here.
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    auto restore_gstate = at_scope_end([=] { CGContextRestoreGState(context); });
    CGContextSetFillColorWithColor(context, m_Colors.GetSpecialColor(ColorMap::Special::Background));
    CGContextFillRect(context, NSRectToCGRect(self.bounds));

    if( !m_Screen )
        return;

    // that's outright stupid, need to be more clever with such scans
    [self scanForBlinkingCharacters];

    const auto font_height = m_FontCache->Height();
    const auto line_start = static_cast<int>(std::floor(dirtyRect.origin.y / font_height));
    const auto line_end = static_cast<int>(std::ceil((dirtyRect.origin.y + dirtyRect.size.height) / font_height));

    auto lock = m_Screen->AcquireLock();

    SetParamsForUserReadableText(context);
    CGContextSetShouldSmoothFonts(context, true);

    for( int i = line_start, bsl = m_Screen->Buffer().BackScreenLines(); i < line_end; ++i ) {
        if( i < bsl ) { // scrollback
            if( auto line = m_Screen->Buffer().LineFromNo(i - bsl); !line.empty() )
                [self DrawLine:line at_y:i sel_y:i - bsl context:context cursor_at:-1];
        }
        else { // real screen
            if( auto line = m_Screen->Buffer().LineFromNo(i - bsl); !line.empty() )
                [self DrawLine:line
                          at_y:i
                         sel_y:i - bsl
                       context:context
                     cursor_at:(m_Screen->CursorY() != i - bsl) ? -1 : m_Screen->CursorX()];
        }
    }
}

namespace {

struct LazyLineRectFiller {
    LazyLineRectFiller(CGContextRef _ctx, double _origin_x, double _origin_y, double _cell_width, double _cell_height)
        : origin_x(_origin_x), origin_y(_origin_y), cell_width(_cell_width), cell_height(_cell_height), ctx(_ctx)
    {
    }

    ~LazyLineRectFiller() { flush(); }

    void draw(CGColorRef _clr, int _x_pos)
    {
        if( clr == nullptr ) {
            clr = _clr;
            start = end = _x_pos;
        }
        else {
            if( clr != _clr || end + 1 != _x_pos ) {
                flush();
                clr = _clr;
                start = end = _x_pos;
            }
            else {
                end = _x_pos;
            }
        }
    }

    void flush()
    {
        if( clr ) {
            CGContextSetFillColorWithColor(ctx, clr);
            auto rc =
                CGRectMake(origin_x + (start * cell_width), origin_y, (end - start + 1) * cell_width, cell_height);
            CGContextFillRect(ctx, rc);
            clr = nullptr;
        }
    }

private:
    CGColorRef clr = nullptr;
    int start, end;
    double origin_x, origin_y, cell_width, cell_height;
    CGContextRef ctx;
};

} // namespace

static const auto g_ClearCGColor = NSColor.clearColor.CGColor;
- (void)DrawLine:(std::span<const term::ScreenBuffer::Space>)_line
            at_y:(int)_y
           sel_y:(int)_sel_y
         context:(CGContextRef)_context
       cursor_at:(int)_cur_x
{
    const double width = m_FontCache->Width();
    const double height = m_FontCache->Height();
    const double descent = m_FontCache->Descent();

    // fill the line background
    {
        LazyLineRectFiller filler(_context, 0., _y * height, width, height);
        const auto bg = m_Colors.GetSpecialColor(ColorMap::Special::Background);
        for( int x = 0; auto char_space : _line ) {
            const auto fg_fill_color = [&] {
                if( char_space.reverse )
                    return char_space.customfg ? m_Colors.GetColor(char_space.foreground.c)
                                               : m_Colors.GetSpecialColor(ColorMap::Special::Foreground);
                else if( char_space.custombg )
                    return m_Colors.GetColor(char_space.background.c);
                else
                    return m_Colors.GetSpecialColor(ColorMap::Special::Background);
            }();

            if( fg_fill_color != bg ) {
                filler.draw(fg_fill_color, x);
            }
            ++x;
        }
    }

    // draw selection if it's here
    if( m_HasSelection ) {
        CGRect rc = {{-1, -1}, {0, 0}};
        if( m_SelStart.y == m_SelEnd.y && m_SelStart.y == _sel_y )
            rc = CGRectMake(m_SelStart.x * width, _y * height, (m_SelEnd.x - m_SelStart.x) * width, height);
        else if( _sel_y < m_SelEnd.y && _sel_y > m_SelStart.y )
            rc = CGRectMake(0, _y * height, self.frame.size.width, height);
        else if( _sel_y == m_SelStart.y )
            rc = CGRectMake(m_SelStart.x * width, _y * height, self.frame.size.width - (m_SelStart.x * width), height);
        else if( _sel_y == m_SelEnd.y )
            rc = CGRectMake(0, _y * height, m_SelEnd.x * width, height);

        if( rc.origin.x >= 0 ) {
            CGContextSetFillColorWithColor(_context, m_Colors.GetSpecialColor(ColorMap::Special::Selection));
            CGContextFillRect(_context, rc);
        }
    }

    // draw cursor if it's here
    if( _cur_x >= 0 )
        [self drawCursor:NSMakeRect(_cur_x * width, _y * height, width, height) context:_context];

    // draw glyphs
    const bool blink_visible = m_BlinkScheduler.Visible();
    CGContextSetShouldAntialias(_context, true);

    auto draw_characters = [&](int _first, int _last) {
        const ScreenBuffer::Space attr = _line[_first];
        if( attr.invisible )
            return;
        if( attr.blink && !blink_visible )
            return;

        // gather all char codes and their coordinates from the run
        std::array<char, 8192> mem_buffer;
        std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
        std::pmr::vector<char32_t> codes(&mem_resource);
        std::pmr::vector<CGPoint> positions(&mem_resource);
        for( int x = _first; x < _last; ++x ) {
            const ScreenBuffer::Space cs = _line[x];
            const bool draw_glyph = cs.l != 0 && cs.l != 32 && cs.l != Screen::MultiCellGlyph;
            if( !draw_glyph )
                continue;
            const double rx = x * width;
            const double ry = (_y * height) + height - descent;
            codes.push_back(cs.l);
            positions.push_back({rx, ry});
        }

        // pick the cells' foreground color
        CGColorRef c = nullptr;
        if( attr.reverse ) {
            if( attr.custombg )
                c = m_Colors.GetColor(attr.background.c);
            else
                c = m_Colors.GetSpecialColor(ColorMap::Special::Background);
        }
        else {
            if( attr.customfg ) {
                if( attr.faint )
                    c = m_Colors.GetFaintColor(attr.foreground.c);
                else
                    c = m_Colors.GetColor(attr.foreground.c);
            }
            else {
                if( attr.bold )
                    c = m_Colors.GetSpecialColor(ColorMap::Special::BoldForeground);
                else
                    c = m_Colors.GetSpecialColor(ColorMap::Special::Foreground);
            }
        }
        CGContextSetFillColorWithColor(_context, c);

        // pick the cells' effective font
        CTCache &font = [&]() -> CTCache & {
            if( attr.bold )
                return attr.italic ? *m_BoldItalicFontCache : *m_BoldFontCache;
            else
                return attr.italic ? *m_ItalicFontCache : *m_FontCache;
        }();

        // Now draw the characters
        font.DrawCharacters(codes.data(), positions.data(), codes.size(), _context);

        if( attr.underline ) {
            CGRect rc;
            rc.origin.x = _first * width;
            rc.origin.y = _y * height + height - 1; /* NEED A REAL UNDERLINE POSITION HERE !!! */
            rc.size.width = (_last - _first) * width;
            rc.size.height = 1.;
            CGContextFillRect(_context, rc);
        }

        if( attr.crossed ) {
            CGRect rc;
            rc.origin.x = _first * width;
            rc.origin.y = _y * height + height / 2.; /* NEED A REAL CROSS POSITION HERE !!! */
            rc.size.width = (_last - _first) * width;
            rc.size.height = 1;
            CGContextFillRect(_context, rc);
        }
    };

    // scan the line to gather spans of characters with same attributes and draw them in batches
    for( int x = 0, start = 0; x < static_cast<int>(_line.size()); ++x ) {
        if( !_line[x].HaveSameAttributes(_line[start]) ) {
            // this char space have different attributes than previous - draw the previous run
            draw_characters(start, x);
            start = x;
        }
        if( x + 1 == static_cast<int>(_line.size()) ) {
            // this is the last char space in this liine - draw what's left
            draw_characters(start, x + 1);
        }
    }
}

- (void)drawCursor:(NSRect)_char_rect context:(CGContextRef)_context
{
    if( !m_ShowCursor )
        return;

    const bool is_wnd_active = self.window.isKeyWindow;

    if( is_wnd_active && m_IsFirstResponder ) {
        if( m_BlinkScheduler.Visible() ) {
            CGContextSetFillColorWithColor(_context, m_Colors.GetSpecialColor(ColorMap::Special::Cursor));
            switch( m_CursorType ) {
                case CursorMode::BlinkingBlock:
                case CursorMode::SteadyBlock:
                    CGContextFillRect(_context, NSRectToCGRect(_char_rect));
                    break;

                case CursorMode::BlinkingUnderline:
                case CursorMode::SteadyUnderline:
                    CGContextFillRect(_context,
                                      CGRectMake(_char_rect.origin.x,
                                                 _char_rect.origin.y + _char_rect.size.height - 2,
                                                 _char_rect.size.width,
                                                 2));
                    break;

                case CursorMode::BlinkingBar:
                case CursorMode::SteadyBar:
                    CGContextFillRect(_context,
                                      CGRectMake(_char_rect.origin.x, _char_rect.origin.y, 1., _char_rect.size.height));
                    break;
            }
        }
    }
    else {
        CGContextSetStrokeColorWithColor(_context, m_Colors.GetSpecialColor(ColorMap::Special::Cursor));
        CGContextSetLineWidth(_context, 1);
        CGContextSetShouldAntialias(_context, false);
        _char_rect.origin.y += 1;
        _char_rect.size.height -= 1;
        CGContextStrokeRect(_context, NSRectToCGRect(_char_rect));
    }
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    const auto font_height = m_FontCache->Height();
    proposedVisibleRect.origin.y = floor((proposedVisibleRect.origin.y / font_height) + 0.5) * font_height;
    return proposedVisibleRect;
}

/**
 * return predicted character position regarding current font setup
 * y values [0...+y should be treated as rows in real terminal screen
 * y values -y...0) should be treated as rows in backscroll. y=-1 mean the closes to real screen row
 * x values are trivial - float x position divided by font's width
 * returned points may not correlate with real lines' lengths or scroll sizes, so they need to be
 * treated carefully
 */
- (SelPoint)projectPoint:(NSPoint)_point
{
    auto y_pos = _point.y;
    y_pos = std::max<CGFloat>(y_pos, 0);

    const int line_predict =
        static_cast<int>(std::floor(y_pos / m_FontCache->Height()) - m_Screen->Buffer().BackScreenLines());

    auto x_pos = _point.x;
    x_pos = std::max<CGFloat>(x_pos, 0);
    const int col_predict = static_cast<int>(std::floor(x_pos / m_FontCache->Width()));
    return SelPoint{col_predict, line_predict};
}

- (void)mouseDown:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }

    if( _event.clickCount > 2 )
        [self handleSelectionWithTripleClick:_event];
    else if( _event.clickCount == 2 )
        [self handleSelectionWithDoubleClick:_event];
    else
        [self handleSelectionWithMouseDragging:_event];
}

- (void)mouseDragged:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)mouseUp:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)rightMouseDown:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)rightMouseDragged:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)rightMouseUp:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)otherMouseDown:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)otherMouseDragged:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)otherMouseUp:(NSEvent *)_event
{
    if( m_MouseEvents != Interpreter::RequestedMouseEvents::None ) {
        [self passMouseEvent:_event];
        return;
    }
}

- (void)handleSelectionWithTripleClick:(NSEvent *)event
{
    NSPoint click_location = [self convertPoint:event.locationInWindow fromView:nil];
    SelPoint position = [self projectPoint:click_location];
    auto lock = m_Screen->AcquireLock();
    if( !m_Screen->Buffer().LineFromNo(position.y).empty() ) {
        m_HasSelection = true;
        m_SelStart = ScreenPoint(0, position.y);
        m_SelEnd = ScreenPoint(m_Screen->Buffer().Width(), position.y);
        while( m_Screen->Buffer().LineWrapped(m_SelStart.y - 1) )
            m_SelStart.y--;
        while( m_Screen->Buffer().LineWrapped(m_SelEnd.y) )
            m_SelEnd.y++;
    }
    else {
        m_HasSelection = false;
        m_SelStart = m_SelEnd = {0, 0};
    }
    [self setNeedsDisplay];
}

- (void)handleSelectionWithDoubleClick:(NSEvent *)event
{
    NSPoint click_location = [self convertPoint:event.locationInWindow fromView:nil];
    SelPoint position = [self projectPoint:click_location];
    auto lock = m_Screen->AcquireLock();
    auto data =
        m_Screen->Buffer().DumpUTF16StringWithLayout(SelPoint(0, position.y - 1), SelPoint(1024, position.y + 1));
    auto &utf16 = data.first;
    auto &layout = data.second;

    if( utf16.empty() )
        return;

    NSString *string = [[NSString alloc] initWithBytesNoCopy:static_cast<void *>(utf16.data())
                                                      length:utf16.size() * sizeof(uint16_t)
                                                    encoding:NSUTF16LittleEndianStringEncoding
                                                freeWhenDone:false];
    if( !string )
        return;

    std::optional<std::pair<SelPoint, SelPoint>> search_result;
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired
                            usingBlock:[&](NSString *, NSRange wordRange, NSRange, BOOL *stop) {
                                if( wordRange.location < layout.size() ) {
                                    auto begin = layout[wordRange.location];
                                    if( position >= begin ) {
                                        auto end = wordRange.location + wordRange.length < layout.size()
                                                       ? layout[wordRange.location + wordRange.length]
                                                       : layout.back();
                                        if( position < end ) {
                                            search_result = std::make_pair(begin, end);
                                            *stop = true;
                                        }
                                    }
                                    else
                                        *stop = YES;
                                }
                                else
                                    *stop = YES;
                            }];

    if( search_result ) {
        m_SelStart = search_result->first;
        m_SelEnd = search_result->second;
    }
    else {
        m_SelStart = position;
        m_SelEnd = SelPoint(position.x + 1, position.y);
    }
    [self setNeedsDisplay];
}

- (void)handleSelectionWithMouseDragging:(NSEvent *)event
{
    // TODO: not a precise selection modification. look at viewer, it has better implementation.

    bool modifying_existing_selection = ([event modifierFlags] & NSEventModifierFlagShift) != 0;
    NSPoint first_loc = [self convertPoint:[event locationInWindow] fromView:nil];

    while( [event type] != NSEventTypeLeftMouseUp ) {
        NSPoint curr_loc = [self convertPoint:[event locationInWindow] fromView:nil];

        SelPoint start = [self projectPoint:first_loc];
        SelPoint end = [self projectPoint:curr_loc];

        if( start > end )
            std::swap(start, end);

        if( modifying_existing_selection && m_HasSelection ) {
            if( end > m_SelStart ) {
                m_SelEnd = end;
                [self setNeedsDisplay];
            }
            else if( end < m_SelStart ) {
                m_SelStart = end;
                [self setNeedsDisplay];
            }
        }
        else if( !m_HasSelection || m_SelEnd != end || m_SelStart != start ) {
            m_HasSelection = true;
            m_SelStart = start;
            m_SelEnd = end;
            [self setNeedsDisplay];
        }

        event = [self.window nextEventMatchingMask:(NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp)];
    }
}

- (void)copy:(id) [[maybe_unused]] _sender
{
    if( !m_HasSelection )
        return;

    if( m_SelStart == m_SelEnd )
        return;

    auto lock = m_Screen->AcquireLock();
    const std::vector<uint16_t> unichars = m_Screen->Buffer().DumpUnicodeString(m_SelStart, m_SelEnd);
    NSString *result = [[NSString alloc] initWithCharacters:unichars.data() length:unichars.size()];
    NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
    [pasteBoard clearContents];
    [pasteBoard declareTypes:@[NSPasteboardTypeString] owner:nil];
    [pasteBoard setString:result forType:NSPasteboardTypeString];
}

- (IBAction)paste:(id) [[maybe_unused]] _sender
{
    NSPasteboard *paste_board = [NSPasteboard generalPasteboard];
    NSString *best_type = [paste_board availableTypeFromArray:[NSArray arrayWithObject:NSPasteboardTypeString]];
    if( !best_type )
        return;

    NSString *text = [paste_board stringForType:NSPasteboardTypeString];
    if( !text )
        return;

    if( const char *utf8 = text.UTF8String )
        m_InputTranslator->ProcessPaste(utf8);
}

- (void)selectAll:(id) [[maybe_unused]] _sender
{
    m_HasSelection = true;
    m_SelStart.y = -m_Screen->Buffer().BackScreenLines();
    m_SelStart.x = 0;
    m_SelEnd.y = m_Screen->Height() - 1;
    m_SelEnd.x = m_Screen->Width();
    [self setNeedsDisplay];
}

- (void)deselectAll:(id) [[maybe_unused]] _sender
{
    m_HasSelection = false;
    [self setNeedsDisplay];
}

- (void)loadSettings
{
    assert(m_Settings);
    self.font = m_Settings->Font();
    self.foregroundColor = m_Settings->ForegroundColor();
    self.boldForegroundColor = m_Settings->BoldForegroundColor();
    self.backgroundColor = m_Settings->BackgroundColor();
    self.selectionColor = m_Settings->SelectionColor();
    self.cursorColor = m_Settings->CursorColor();
    self.ansiColor0 = m_Settings->AnsiColor0();
    self.ansiColor1 = m_Settings->AnsiColor1();
    self.ansiColor2 = m_Settings->AnsiColor2();
    self.ansiColor3 = m_Settings->AnsiColor3();
    self.ansiColor4 = m_Settings->AnsiColor4();
    self.ansiColor5 = m_Settings->AnsiColor5();
    self.ansiColor6 = m_Settings->AnsiColor6();
    self.ansiColor7 = m_Settings->AnsiColor7();
    self.ansiColor8 = m_Settings->AnsiColor8();
    self.ansiColor9 = m_Settings->AnsiColor9();
    self.ansiColorA = m_Settings->AnsiColorA();
    self.ansiColorB = m_Settings->AnsiColorB();
    self.ansiColorC = m_Settings->AnsiColorC();
    self.ansiColorD = m_Settings->AnsiColorD();
    self.ansiColorE = m_Settings->AnsiColorE();
    self.ansiColorF = m_Settings->AnsiColorF();
    m_FPS.fps = m_Settings->MaxFPS();
    self.cursorMode = m_Settings->CursorMode();
}

- (std::shared_ptr<nc::term::Settings>)settings
{
    return m_Settings;
}

- (void)setSettings:(std::shared_ptr<nc::term::Settings>)settings
{
    if( m_Settings == settings )
        return;

    if( m_Settings )
        m_Settings->StopChangesObserving(m_SettingsNotificationTicket);

    m_Settings = settings;
    [self loadSettings];

    __weak NCTermView *weak_self = self;
    m_SettingsNotificationTicket = settings->StartChangesObserving([weak_self] {
        if( auto s = weak_self )
            [s loadSettings];
    });
}

- (nc::term::CursorMode)cursorMode
{
    return m_CursorType;
}

- (void)setCursorMode:(nc::term::CursorMode)cursorMode
{
    if( m_CursorType != cursorMode ) {
        m_CursorType = cursorMode;
        [self updateBlinkSheduling];
        self.needsDisplay = true;
    }
}

- (NSFont *)font
{
    return m_Font;
}

- (void)setFont:(NSFont *)font
{
    if( m_Font != font ) {
        m_Font = font;
        m_BoldFont = [NSFontManager.sharedFontManager convertFont:m_Font toHaveTrait:NSBoldFontMask];
        m_ItalicFont = [NSFontManager.sharedFontManager convertFont:m_Font toHaveTrait:NSItalicFontMask];
        m_BoldItalicFont = [NSFontManager.sharedFontManager convertFont:m_BoldFont toHaveTrait:NSItalicFontMask];

        auto &creg = g_CacheRegistry;
        m_FontCache = creg.CacheForFont(base::CFPtr<CTFontRef>((__bridge CTFontRef)m_Font));
        m_BoldFontCache = creg.CacheForFont(base::CFPtr<CTFontRef>((__bridge CTFontRef)m_BoldFont));
        m_ItalicFontCache = creg.CacheForFont(base::CFPtr<CTFontRef>((__bridge CTFontRef)m_ItalicFont));
        m_BoldItalicFontCache = creg.CacheForFont(base::CFPtr<CTFontRef>((__bridge CTFontRef)m_BoldItalicFont));
        self.needsDisplay = true;
    }
}

- (NSColor *)foregroundColor
{
    return [NSColor colorWithCGColor:m_Colors.GetSpecialColor(ColorMap::Special::Foreground)];
}

- (void)setForegroundColor:(NSColor *)foregroundColor
{
    if( ![foregroundColor isEqualTo:self.foregroundColor] ) {
        m_Colors.SetSpecialColor(ColorMap::Special::Foreground, foregroundColor);
        self.needsDisplay = true;
    }
}

- (NSColor *)boldForegroundColor
{
    return [NSColor colorWithCGColor:m_Colors.GetSpecialColor(ColorMap::Special::BoldForeground)];
}

- (void)setBoldForegroundColor:(NSColor *)boldForegroundColor
{
    if( ![boldForegroundColor isEqualTo:self.boldForegroundColor] ) {
        m_Colors.SetSpecialColor(ColorMap::Special::BoldForeground, boldForegroundColor);
        self.needsDisplay = true;
    }
}

- (NSColor *)backgroundColor
{
    return [NSColor colorWithCGColor:m_Colors.GetSpecialColor(ColorMap::Special::Background)];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    if( ![backgroundColor isEqualTo:self.backgroundColor] ) {
        m_Colors.SetSpecialColor(ColorMap::Special::Background, backgroundColor);
        self.needsDisplay = true;
    }
}

- (NSColor *)selectionColor
{
    return [NSColor colorWithCGColor:m_Colors.GetSpecialColor(ColorMap::Special::Selection)];
}

- (void)setSelectionColor:(NSColor *)selectionColor
{
    if( ![selectionColor isEqualTo:self.selectionColor] ) {
        m_Colors.SetSpecialColor(ColorMap::Special::Selection, selectionColor);
        self.needsDisplay = true;
    }
}

- (NSColor *)cursorColor
{
    return [NSColor colorWithCGColor:m_Colors.GetSpecialColor(ColorMap::Special::Cursor)];
}

- (void)setCursorColor:(NSColor *)cursorColor
{
    if( ![cursorColor isEqualTo:self.cursorColor] ) {
        m_Colors.SetSpecialColor(ColorMap::Special::Cursor, cursorColor);
        self.needsDisplay = true;
    }
}

// NOLINTBEGIN(bugprone-macro-parentheses)
#define ANSI_COLOR(getter, setter, index)                                                                              \
    -(NSColor *)getter                                                                                                 \
    {                                                                                                                  \
        return [NSColor colorWithCGColor:m_Colors.GetColor(index)];                                                    \
    }                                                                                                                  \
    -(void)setter : (NSColor *)color                                                                                   \
    {                                                                                                                  \
        if( ![color isEqualTo:self.getter] ) {                                                                         \
            m_Colors.SetANSIColor(index, color);                                                                       \
            self.needsDisplay = true;                                                                                  \
        }                                                                                                              \
    }
// NOLINTEND(bugprone-macro-parentheses)

ANSI_COLOR(ansiColor0, setAnsiColor0, 0);
ANSI_COLOR(ansiColor1, setAnsiColor1, 1);
ANSI_COLOR(ansiColor2, setAnsiColor2, 2);
ANSI_COLOR(ansiColor3, setAnsiColor3, 3);
ANSI_COLOR(ansiColor4, setAnsiColor4, 4);
ANSI_COLOR(ansiColor5, setAnsiColor5, 5);
ANSI_COLOR(ansiColor6, setAnsiColor6, 6);
ANSI_COLOR(ansiColor7, setAnsiColor7, 7);
ANSI_COLOR(ansiColor8, setAnsiColor8, 8);
ANSI_COLOR(ansiColor9, setAnsiColor9, 9);
ANSI_COLOR(ansiColorA, setAnsiColorA, 10);
ANSI_COLOR(ansiColorB, setAnsiColorB, 11);
ANSI_COLOR(ansiColorC, setAnsiColorC, 12);
ANSI_COLOR(ansiColorD, setAnsiColorD, 13);
ANSI_COLOR(ansiColorE, setAnsiColorE, 14);
ANSI_COLOR(ansiColorF, setAnsiColorF, 15);

#undef ANSI_COLOR

- (NSPoint)beginningOfScreenLine:(int)_line_number
{
    if( _line_number <= 0 )
        return NSMakePoint(0., 0.);
    return NSMakePoint(0., _line_number * m_FontCache->Height());
}

- (void)viewStatusDidChange
{
    const auto wnd = self.window;
    const bool is_wnd_active = wnd.isKeyWindow;
    m_CursorShouldBlink = is_wnd_active && m_IsFirstResponder;
    [self updateBlinkSheduling];
    self.needsDisplay = true;
}

- (void)updateBlinkSheduling
{
    const bool cursor_blink = m_AllowCursorBlinking && m_CursorShouldBlink && !IsSteady(m_CursorType);
    const bool spaces_blink = m_HasVisibleBlinkingSpaces;
    m_BlinkScheduler.Enable(cursor_blink || spaces_blink);
}

- (void)scanForBlinkingCharacters
{
    const bool has = [self visibleLinesHaveBlinkingCharacters];
    if( has != m_HasVisibleBlinkingSpaces ) {
        m_HasVisibleBlinkingSpaces = has;
        [self updateBlinkSheduling];
    }
}

static constexpr bool LineHasBlinkingCharacters(std::span<const ScreenBuffer::Space> _range) noexcept
{
    return std::ranges::any_of(_range, [](const auto &space) { return space.blink; });
}

- (bool)visibleLinesHaveBlinkingCharacters
{
    const auto &buffer = m_Screen->Buffer();
    const auto rect = self.visibleRect;
    const auto font_height = m_FontCache->Height();
    const auto line_start = static_cast<int>(std::floor(rect.origin.y / font_height));
    const auto line_end = static_cast<int>(std::ceil((rect.origin.y + rect.size.height) / font_height));

    auto lock = m_Screen->AcquireLock(); // WTF??
    const auto bsl = static_cast<int>(buffer.BackScreenLines());
    for( int line_index = line_start; line_index != line_end; ++line_index ) {
        if( LineHasBlinkingCharacters(buffer.LineFromNo(line_index - bsl)) )
            return true;
    }
    return false;
}

- (void)setMouseEvents:(Interpreter::RequestedMouseEvents)_mouseEvents
{
    if( _mouseEvents == m_MouseEvents )
        return;
    m_MouseEvents = _mouseEvents;
}

- (Interpreter::RequestedMouseEvents)mouseEvents
{
    return m_MouseEvents;
}

static constexpr InputTranslator::MouseEvent::Type NSEventTypeToMouseEventType(NSEventType _type) noexcept
{
    using MouseEvent = InputTranslator::MouseEvent;
    switch( _type ) {
        case NSEventTypeLeftMouseDown:
            return MouseEvent::LDown;
        case NSEventTypeLeftMouseDragged:
            return MouseEvent::LDrag;
        case NSEventTypeLeftMouseUp:
            return MouseEvent::LUp;
        case NSEventTypeOtherMouseDown:
            return MouseEvent::MDown;
        case NSEventTypeOtherMouseDragged:
            return MouseEvent::MDrag;
        case NSEventTypeOtherMouseUp:
            return MouseEvent::MUp;
        case NSEventTypeRightMouseDown:
            return MouseEvent::RDown;
        case NSEventTypeRightMouseDragged:
            return MouseEvent::RDrag;
        case NSEventTypeRightMouseUp:
            return MouseEvent::RUp;
        default:
            return MouseEvent::LDown;
    }
}

- (void)passMouseEvent:(NSEvent *)_event
{
    constexpr auto has = [](const auto &_container, const auto &_value) -> bool {
        return std::find(std::begin(_container), std::end(_container), _value) != std::end(_container);
    };

    const NSEventType type = _event.type;
    const utility::NSEventModifierFlagsHolder flags = _event.modifierFlags;
    const NSPoint location_px = [self convertPoint:_event.locationInWindow fromView:nil];
    const SelPoint location_cell = [self projectPoint:location_px];
    const bool location_cell_changed = location_cell == m_LastMouseCell;
    m_LastMouseCell = location_cell;

    if( m_MouseEvents == Interpreter::RequestedMouseEvents::X10 ) {
        constexpr std::array<NSEventType, 3> types = {
            NSEventTypeLeftMouseDown, NSEventTypeRightMouseDown, NSEventTypeOtherMouseDown};
        if( !has(types, type) )
            return;

        InputTranslator::MouseEvent evt;
        evt.type = NSEventTypeToMouseEventType(type);
        evt.x = static_cast<short>(location_cell.x);
        evt.y = static_cast<short>(location_cell.y);
        m_InputTranslator->ProcessMouseEvent(evt);
    }
    else if( m_MouseEvents == Interpreter::RequestedMouseEvents::Normal ) {
        constexpr std::array<NSEventType, 8> types = {NSEventTypeLeftMouseDown,
                                                      NSEventTypeLeftMouseUp,
                                                      NSEventTypeOtherMouseDown,
                                                      NSEventTypeOtherMouseUp,
                                                      NSEventTypeRightMouseDown,
                                                      NSEventTypeRightMouseUp};

        if( !has(types, type) )
            return;

        InputTranslator::MouseEvent evt;
        evt.type = NSEventTypeToMouseEventType(type);
        evt.x = static_cast<short>(location_cell.x);
        evt.y = static_cast<short>(location_cell.y);
        evt.shift = flags.is_shift();
        evt.alt = flags.is_option();
        evt.control = flags.is_control();
        m_InputTranslator->ProcessMouseEvent(evt);
    }
    else if( m_MouseEvents == Interpreter::RequestedMouseEvents::ButtonTracking ) {
        constexpr std::array<NSEventType, 9> types = {NSEventTypeLeftMouseDown,
                                                      NSEventTypeLeftMouseDragged,
                                                      NSEventTypeLeftMouseUp,
                                                      NSEventTypeOtherMouseDown,
                                                      NSEventTypeOtherMouseDragged,
                                                      NSEventTypeOtherMouseUp,
                                                      NSEventTypeRightMouseDown,
                                                      NSEventTypeRightMouseDragged,
                                                      NSEventTypeRightMouseUp};
        constexpr std::array<NSEventType, 3> movement_types = {
            NSEventTypeLeftMouseDragged, NSEventTypeOtherMouseDragged, NSEventTypeRightMouseDragged};

        if( !has(types, type) )
            return;

        if( !location_cell_changed && has(movement_types, type) )
            return;

        InputTranslator::MouseEvent evt;
        evt.type = NSEventTypeToMouseEventType(type);
        evt.x = static_cast<short>(location_cell.x);
        evt.y = static_cast<short>(location_cell.y);
        evt.shift = flags.is_shift();
        evt.alt = flags.is_option();
        evt.control = flags.is_control();
        m_InputTranslator->ProcessMouseEvent(evt);
    }
    else if( m_MouseEvents == Interpreter::RequestedMouseEvents::Any ) {
        constexpr std::array<NSEventType, 9> types = {NSEventTypeLeftMouseDown,
                                                      NSEventTypeLeftMouseDragged,
                                                      NSEventTypeLeftMouseUp,
                                                      NSEventTypeOtherMouseDown,
                                                      NSEventTypeOtherMouseDragged,
                                                      NSEventTypeOtherMouseUp,
                                                      NSEventTypeRightMouseDown,
                                                      NSEventTypeRightMouseDragged,
                                                      NSEventTypeRightMouseUp};
        constexpr std::array<NSEventType, 3> movement_types = {
            NSEventTypeLeftMouseDragged, NSEventTypeOtherMouseDragged, NSEventTypeRightMouseDragged};
        // plus moved?

        if( !has(types, type) )
            return;

        if( !location_cell_changed && has(movement_types, type) )
            return;

        InputTranslator::MouseEvent evt;
        evt.type = NSEventTypeToMouseEventType(type);
        evt.x = static_cast<short>(location_cell.x);
        evt.y = static_cast<short>(location_cell.y);
        evt.shift = flags.is_shift();
        evt.alt = flags.is_option();
        evt.control = flags.is_control();
        m_InputTranslator->ProcessMouseEvent(evt);
    }
}

@end
