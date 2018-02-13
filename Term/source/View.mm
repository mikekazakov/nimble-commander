// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/HexadecimalColor.h>
#include <Utility/FontCache.h>
#include <Utility/FontExtras.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/BlinkingCaret.h>
#include <Utility/OrthodoxMonospace.h>
#include <Habanero/algo.h>
#include "View.h"
#include "Screen.h"
#include "Parser.h"
#include "Settings.h"

using namespace nc;
using namespace nc::term;

static const NSEdgeInsets g_Insets = { 2., 5., 2., 5. };

using SelPoint = term::ScreenPoint;

static inline bool IsBoxDrawingCharacter(uint32_t _ch)
{
    return _ch >= 0x2500 && _ch <= 0x257F;
}

@implementation NCTermView
{
    shared_ptr<FontCache>   m_FontCache;
    Screen                 *m_Screen;
    Parser                 *m_Parser;
    
    int                     m_LastScreenFullHeight;
    bool                    m_HasSelection;
    bool                    m_ReportsSizeByOccupiedContent;
    TermViewCursor          m_CursorType;
    SelPoint                m_SelStart;
    SelPoint                m_SelEnd;
    
    FPSLimitedDrawer       *m_FPS;
    NSSize                  m_IntrinsicSize;
    unique_ptr<BlinkingCaret> m_BlinkingCaret;
    NSFont                 *m_Font;
    NSColor                *m_ForegroundColor;
    NSColor                *m_BoldForegroundColor;
    NSColor                *m_BackgroundColor;
    NSColor                *m_SelectionColor;
    NSColor                *m_CursorColor;
    NSColor                *m_AnsiColors[16];
    shared_ptr<Settings>    m_Settings;
    int                     m_SettingsNotificationTicket;
}

@synthesize fpsDrawer = m_FPS;
@synthesize reportsSizeByOccupiedContent = m_ReportsSizeByOccupiedContent;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_SettingsNotificationTicket = 0;
        m_CursorType = TermViewCursor::Block;
        m_BlinkingCaret = make_unique<BlinkingCaret>(self);
        m_LastScreenFullHeight = 0;
        m_HasSelection = false;
        m_ReportsSizeByOccupiedContent = false;
        m_FPS = [[FPSLimitedDrawer alloc] initWithView:self];
        m_FPS.fps = 60;
        m_IntrinsicSize = NSMakeSize(NSViewNoInstrinsicMetric, frame.size.height);
        self.settings = DefaultSettings::SharedDefaultSettings();
    }
    return self;
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
    self.needsDisplay = true;
    [self discardCursorRects];
    [self resetCursorRects];
    return true;
}

- (BOOL)resignFirstResponder
{
    self.needsDisplay = true;
    [self discardCursorRects];
    return true;
}

-(BOOL) isOpaque
{
	return YES;
}

- (void)resetCursorRects
{
    if( self == self.window.firstResponder )
        [self addCursorRect:self.frame cursor:NSCursor.IBeamCursor];
}

- (term::Parser *)parser
{
    return m_Parser;
}

- (const FontCache&) fontCache
{
    return *m_FontCache;
}

- (void) AttachToScreen:(term::Screen*)_scr
{
    m_Screen = _scr;
}

- (void) AttachToParser:(term::Parser*)_par
{
    m_Parser = _par;
}

- (void) setAllowCursorBlinking:(bool)allowCursorBlinking
{
    m_BlinkingCaret->SetEnabled(allowCursorBlinking);
}

- (bool) allowCursorBlinking
{
    return m_BlinkingCaret->Enabled();
}

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];
    if ( [character length] == 1 )
        m_HasSelection = false;

    m_Parser->ProcessKeyDown(event);
    [self scrollToBottom];
}

- (NSSize) intrinsicContentSize
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

+ (NSEdgeInsets) insets
{
    return g_Insets;
}

+ (NSSize) insetSize:(NSSize)_sz
{
    _sz.width -= g_Insets.left + g_Insets.right;
    if( _sz.width < 0 )
        _sz.width = 0;
    
    _sz.height -= g_Insets.top + g_Insets.bottom;
    if( _sz.height < 0 )
        _sz.height = 0;
    
    return _sz;
}

- (void)adjustSizes:(bool)_mandatory
{
    const int full_lines_height = self.fullScreenLinesHeight;
    if( full_lines_height == m_LastScreenFullHeight && _mandatory == false )
        return;
    
    m_LastScreenFullHeight = full_lines_height;
    
    const auto clipview = self.enclosingScrollView.contentView;
    const auto size_without_insets = [NCTermView insetSize:NSMakeSize(self.frame.size.width, clipview.frame.size.height)];
    const auto full_lines_height_px = full_lines_height * m_FontCache->Height(); // full content height
    const auto rest = size_without_insets.height - floor(size_without_insets.height / m_FontCache->Height()) * m_FontCache->Height();

    m_IntrinsicSize = NSMakeSize(NSViewNoInstrinsicMetric, full_lines_height_px + rest + g_Insets.top + g_Insets.bottom);
    [self invalidateIntrinsicContentSize];
    [self.enclosingScrollView layoutSubtreeIfNeeded];
    [self scrollToBottom];
}

- (void) scrollToBottom
{
    auto scrollview = self.enclosingScrollView;
    auto clipview = scrollview.contentView;
    
    auto h1 = self.frame.size.height;
    auto h2 = scrollview.contentSize.height;
    if( h1 > h2 ) {
        auto p = NSMakePoint(0,
                             self.superview.isFlipped ?
                                (self.frame.size.height - scrollview.contentSize.height) :
                                0
                             );
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
    auto restore_gstate = at_scope_end([=]{ CGContextRestoreGState(context); });
    CGContextSetFillColorWithColor( context, m_BackgroundColor.CGColor );
    CGContextFillRect( context, NSRectToCGRect(self.bounds) );
    
    if( !m_Screen )
        return;
    
    CGContextTranslateCTM(context, g_Insets.left, g_Insets.top);

    int line_start=0, line_end=0;
    const auto clipviewbounds = self.enclosingScrollView.contentView.bounds;
    const auto effective_height = [NCTermView insetSize:NSMakeSize(0, clipviewbounds.size.height)].height;
    if( self.superview.isFlipped ) { // regular terminal
        line_start = floor( (clipviewbounds.origin.y + g_Insets.top ) / m_FontCache->Height());
        line_end   = line_start + ceil(effective_height / m_FontCache->Height());
    }
    else {  // overlapped terminal
        line_end = ceil( (self.bounds.size.height - clipviewbounds.origin.y) / m_FontCache->Height());
        line_start = line_end - ceil(effective_height / m_FontCache->Height());
    }
    
    
    auto lock = m_Screen->AcquireLock();
    
    oms::SetParamsForUserReadableText(context, m_FontCache.get());
    CGContextSetShouldSmoothFonts(context, true);

    for(int i = line_start, bsl = m_Screen->Buffer().BackScreenLines();
        i < line_end;
        ++i) {
        if(i < bsl) { // scrollback
            if(auto line = m_Screen->Buffer().LineFromNo(i - bsl))
                [self DrawLine:line
                          at_y:i
                         sel_y:i - bsl
                       context:context
                     cursor_at:-1];
        }
        else { // real screen
            if(auto line = m_Screen->Buffer().LineFromNo(i - bsl))
                [self DrawLine:line
                          at_y:i
                         sel_y:i - bsl
                       context:context
                     cursor_at:(m_Screen->CursorY() != i - bsl) ? -1 : m_Screen->CursorX()];
        }
    }
}

static const auto g_ClearCGColor = NSColor.clearColor.CGColor;
- (void) DrawLine:(term::ScreenBuffer::RangePair<const term::ScreenBuffer::Space>)_line
             at_y:(int)_y
            sel_y:(int)_sel_y
          context:(CGContextRef)_context
        cursor_at:(int)_cur_x
{
    auto current_color = g_ClearCGColor;
    int x = 0;

    for( auto char_space: _line ) {
        const auto fg_fill_color = char_space.reverse ?
            ( char_space.foreground != ScreenColors::Default ?
                m_AnsiColors[char_space.foreground] :
                m_ForegroundColor).CGColor :
            ( char_space.background != ScreenColors::Default ?
                m_AnsiColors[char_space.background] :
                m_BackgroundColor).CGColor;
        
        if( !CGColorEqualToColor(fg_fill_color, m_BackgroundColor.CGColor) ) {
            if( !CGColorEqualToColor(fg_fill_color, current_color) )  {
                current_color = fg_fill_color;
                CGContextSetFillColorWithColor(_context, current_color );
            }
            
            CGContextFillRect(_context,
                              CGRectMake(x * m_FontCache->Width(),
                                         _y * m_FontCache->Height(),
                                         m_FontCache->Width(),
                                         m_FontCache->Height()));
        }
        ++x;
    }
    
    // draw selection if it's here
    if( m_HasSelection ) {
        CGRect rc = {{-1, -1}, {0, 0}};
        if(m_SelStart.y == m_SelEnd.y && m_SelStart.y == _sel_y)
            rc = CGRectMake(m_SelStart.x * m_FontCache->Width(),
                            _y * m_FontCache->Height(),
                            (m_SelEnd.x - m_SelStart.x) * m_FontCache->Width(),
                            m_FontCache->Height());
        else if(_sel_y < m_SelEnd.y && _sel_y > m_SelStart.y)
            rc = CGRectMake(0,
                            _y * m_FontCache->Height(),
                            self.frame.size.width,
                            m_FontCache->Height());
        else if(_sel_y == m_SelStart.y)
            rc = CGRectMake(m_SelStart.x * m_FontCache->Width(),
                            _y * m_FontCache->Height(),
                            self.frame.size.width - m_SelStart.x * m_FontCache->Width(),
                            m_FontCache->Height());
        else if(_sel_y == m_SelEnd.y)
            rc = CGRectMake(0,
                            _y * m_FontCache->Height(),
                            m_SelEnd.x * m_FontCache->Width(),
                            m_FontCache->Height());
        
        if( rc.origin.x >= 0 ) {
            CGContextSetFillColorWithColor( _context, m_SelectionColor.CGColor );
            CGContextFillRect( _context, rc );
        }
    }
    
    // draw cursor if it's here
    if(_cur_x >= 0)
        [self drawCursor:NSMakeRect(_cur_x * m_FontCache->Width(),
                                   _y * m_FontCache->Height(),
                                   m_FontCache->Width(),
                                   m_FontCache->Height())
                 context:_context];
    
    // draw glyphs
    x = 0;
    current_color = g_ClearCGColor;
    CGContextSetShouldAntialias(_context, true);
    
    for( const auto char_space: _line ) {
        auto c = m_ForegroundColor.CGColor;

        if( char_space.reverse ) {
            c = char_space.background != ScreenColors::Default ?
                m_AnsiColors[char_space.background].CGColor :
                m_BackgroundColor.CGColor;
        } else {
            int foreground = char_space.foreground;
            if( foreground != ScreenColors::Default ){
                if( char_space.intensity )
                    foreground += 8;
                c = m_AnsiColors[foreground].CGColor;
            } else {
                if( char_space.intensity )
                    c =  m_BoldForegroundColor.CGColor;
            }
        }
        
        if(char_space.l != 0 &&
           char_space.l != 32 &&
           char_space.l != Screen::MultiCellGlyph
           ) {
            if( !CGColorEqualToColor(c, current_color) )  {
                current_color = c;
                CGContextSetFillColorWithColor(_context, current_color );
            }
            
            bool pop = false;
            if( IsBoxDrawingCharacter(char_space.l) ) {
                CGContextSaveGState(_context);
                CGContextSetShouldAntialias(_context, false);
                pop = true;
                
            }
            
            oms::DrawSingleUniCharXY(char_space.l, x, _y, _context, m_FontCache.get());
            
            if(char_space.c1 != 0)
                oms::DrawSingleUniCharXY(char_space.c1, x, _y, _context, m_FontCache.get());
            if(char_space.c2 != 0)
                oms::DrawSingleUniCharXY(char_space.c2, x, _y, _context, m_FontCache.get());
            
            if(pop)
                CGContextRestoreGState(_context);
        }        
        
        if( char_space.underline ) {
            /* NEED A REAL UNDERLINE POSITION HERE !!! */
            // need to set color here?
            CGRect rc;
            rc.origin.x = x * m_FontCache->Width();
            rc.origin.y = _y * m_FontCache->Height() + m_FontCache->Height() - 1;
            rc.size.width = m_FontCache->Width();
            rc.size.height = 1;
            CGContextFillRect(_context, rc);
        }
        
        ++x;
    }
}

- (void)drawCursor:(NSRect)_char_rect context:(CGContextRef)_context
{
    const bool is_wnd_active = NSView.focusView.window.isKeyWindow;
    const bool is_first_responder = self.window.firstResponder == self;
    
    if( is_wnd_active && is_first_responder ) {
        m_BlinkingCaret->ScheduleNextRedraw(); // be sure not to call Shedule... when view is not active
        if( m_BlinkingCaret->Visible() ) {
            CGContextSetFillColorWithColor(_context, m_CursorColor.CGColor );
            switch (m_CursorType) {
                case TermViewCursor::Block:
                    CGContextFillRect(_context, NSRectToCGRect(_char_rect));
                    break;
                    
                case TermViewCursor::Underline:
                    CGContextFillRect(_context,
                                      CGRectMake(_char_rect.origin.x,
                                                 _char_rect.origin.y + _char_rect.size.height - 2,
                                                 _char_rect.size.width,
                                                 2));
                    break;
                    
                case TermViewCursor::VerticalBar:
                    CGContextFillRect(_context,
                                      CGRectMake(_char_rect.origin.x, _char_rect.origin.y, 1., _char_rect.size.height)
                                      );
                    break;
            }
        }
    }
    else {
        CGContextSetStrokeColorWithColor(_context, m_CursorColor.CGColor );
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
    proposedVisibleRect.origin.y = floor(proposedVisibleRect.origin.y/font_height + 0.5) * font_height;
    return proposedVisibleRect;
}

/**
 * return predicted character position regarding current font setup
 * y values [0...+y should be treated as rows in real terminal screen
 * y values -y...0) should be treated as rows in backscroll. y=-1 mean the closes to real screen row
 * x values are trivial - float x position divided by font's width
 * returned points may not correlate with real lines' lengths or scroll sizes, so they need to be treated carefully
 */
- (SelPoint)projectPoint:(NSPoint)_point
{
    auto y_pos = _point.y - g_Insets.top;
    if( y_pos < 0 )
        y_pos = 0;
    
    int line_predict = floor(y_pos / m_FontCache->Height()) - m_Screen->Buffer().BackScreenLines();
    
    auto x_pos = _point.x - g_Insets.left;
    if( x_pos < 0 )
        x_pos = 0;
    int col_predict = floor(x_pos / m_FontCache->Width());
    return SelPoint{col_predict, line_predict};
}

- (void) mouseDown:(NSEvent *)_event
{
    if(_event.clickCount > 2)
        [self handleSelectionWithTripleClick:_event];
    else if(_event.clickCount == 2 )
        [self handleSelectionWithDoubleClick:_event];
    else
        [self handleSelectionWithMouseDragging:_event];
}

- (void) handleSelectionWithTripleClick:(NSEvent *) event
{
    NSPoint click_location = [self convertPoint:event.locationInWindow fromView:nil];
    SelPoint position = [self projectPoint:click_location];
    auto lock = m_Screen->AcquireLock();
    if( m_Screen->Buffer().LineFromNo(position.y) ) {
        m_HasSelection = true;
        m_SelStart = ScreenPoint( 0, position.y );
        m_SelEnd = ScreenPoint( m_Screen->Buffer().Width(), position.y );
        while( m_Screen->Buffer().LineWrapped(m_SelStart.y-1) )
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

- (void) handleSelectionWithDoubleClick:(NSEvent *) event
{
    NSPoint click_location = [self convertPoint:event.locationInWindow fromView:nil];
    SelPoint position = [self projectPoint:click_location];
    auto lock = m_Screen->AcquireLock();
    auto data = m_Screen->Buffer().DumpUTF16StringWithLayout(SelPoint(0, position.y-1), SelPoint(1024, position.y+1));
    auto &utf16 = data.first;
    auto &layout = data.second;

    if( utf16.empty() )
        return;
    
    NSString *string = [[NSString alloc] initWithBytesNoCopy:(void*)utf16.data()
                                                      length:utf16.size()*sizeof(uint16_t)
                                                    encoding:NSUTF16LittleEndianStringEncoding
                                                freeWhenDone:false];
    if( !string )
        return;
    
    optional<pair<SelPoint, SelPoint>> search_result;
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired
                            usingBlock:[&](NSString*,
                                           NSRange wordRange,
                                           NSRange,
                                           BOOL *stop){
                                if( wordRange.location < layout.size() ) {
                                    auto begin = layout[wordRange.location];
                                    if( position >= begin ) {
                                        auto end = wordRange.location + wordRange.length < layout.size() ?
                                                layout[wordRange.location + wordRange.length] :
                                                layout.back();
                                        if( position < end ) {
                                            search_result = make_pair(begin, end);
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
        m_SelEnd = SelPoint(position.x+1, position.y);
    }
    [self setNeedsDisplay];
}

- (void) handleSelectionWithMouseDragging: (NSEvent*) event
{
    // TODO: not a precise selection modification. look at viewer, it has better implementation.
    
    bool modifying_existing_selection = ([event modifierFlags] & NSShiftKeyMask) ? true : false;
    NSPoint first_loc = [self convertPoint:[event locationInWindow] fromView:nil];
    
    while ([event type]!=NSLeftMouseUp)
    {
        NSPoint curr_loc = [self convertPoint:[event locationInWindow] fromView:nil];
        
        SelPoint start = [self projectPoint:first_loc];
        SelPoint end   = [self projectPoint:curr_loc];
        
        if(start > end)
            swap(start, end);
        
        
        if(modifying_existing_selection && m_HasSelection)
        {
            if(end > m_SelStart) {
                m_SelEnd = end;
                [self setNeedsDisplay];
            }
            else if(end < m_SelStart) {
                m_SelStart = end;
                [self setNeedsDisplay];
            }
        }
        else if(!m_HasSelection || m_SelEnd != end || m_SelStart != start)
        {
            m_HasSelection = true;
            m_SelStart = start;
            m_SelEnd = end;
            [self setNeedsDisplay];
        }

        event = [self.window nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
    }
}

- (void)copy:(id)sender
{
    if(!m_HasSelection)
        return;
    
    if(m_SelStart == m_SelEnd)
        return;

    auto lock = m_Screen->AcquireLock();
    vector<uint32_t> unichars = m_Screen->Buffer().DumpUnicodeString(m_SelStart, m_SelEnd);
    
    NSString *result = [[NSString alloc] initWithBytes:unichars.data()
                                                length:unichars.size() * sizeof(uint32_t)
                                              encoding:NSUTF32LittleEndianStringEncoding];
    NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
    [pasteBoard clearContents];
    [pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
    [pasteBoard setString:result forType:NSStringPboardType];
}

- (IBAction)paste:(id)sender
{    
    NSPasteboard *paste_board = [NSPasteboard generalPasteboard];
    NSString *best_type = [paste_board availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    if(!best_type)
        return;
    
    NSString *text = [paste_board stringForType:NSStringPboardType];
    if(!text)
        return;
    m_Parser->PushRawTaskInput(text);
}

- (void)selectAll:(id)sender
{
    m_HasSelection = true;
    m_SelStart.y = -m_Screen->Buffer().BackScreenLines();
    m_SelStart.x = 0;
    m_SelEnd.y = m_Screen->Height()-1;
    m_SelEnd.x = m_Screen->Width();
    [self setNeedsDisplay];
}

- (void)deselectAll:(id)sender
{
    m_HasSelection = false;
    [self setNeedsDisplay];
}

- (void)loadSettings
{
    assert( m_Settings );
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

- (shared_ptr<nc::term::Settings>) settings
{
    return m_Settings;
}

- (void)setSettings:(shared_ptr<nc::term::Settings>)settings
{
    if( m_Settings == settings )
        return;

    if( m_Settings )
        m_Settings->StopChangesObserving(m_SettingsNotificationTicket);

    m_Settings = settings;
    [self loadSettings];
    
    __weak NCTermView* weak_self = self;
    m_SettingsNotificationTicket = settings->StartChangesObserving([weak_self]{
        if( auto s = weak_self )
            [s loadSettings];
    });
}

- (nc::term::CursorMode) cursorMode
{
    return m_CursorType;
}

- (void)setCursorMode:(nc::term::CursorMode)cursorMode
{
    if( m_CursorType != cursorMode ) {
        m_CursorType = cursorMode;
        self.needsDisplay = true;
    }
}

- (NSFont*) font
{
    return m_Font;
}

- (void) setFont:(NSFont *)font
{
    if( m_Font != font ) {
        m_Font = font;
        m_FontCache = FontCache::FontCacheFromFont( (__bridge CTFontRef)m_Font );
        self.needsDisplay = true;
    }
}

- (NSColor*) foregroundColor
{
    return m_ForegroundColor;
}

- (void)setForegroundColor:(NSColor *)foregroundColor
{
    if( m_ForegroundColor != foregroundColor ) {
        m_ForegroundColor = foregroundColor;
        self.needsDisplay = true;
    }
}

- (NSColor*)boldForegroundColor
{
    return m_BoldForegroundColor;
}

- (void)setBoldForegroundColor:(NSColor *)boldForegroundColor
{
    if( m_BoldForegroundColor != boldForegroundColor ) {
        m_BoldForegroundColor = boldForegroundColor;
        self.needsDisplay = true;
    }
}

- (NSColor*) backgroundColor
{
    return m_BackgroundColor;
}

- (void) setBackgroundColor:(NSColor *)backgroundColor
{
    if( m_BackgroundColor != backgroundColor ) {
        m_BackgroundColor = backgroundColor;
        self.needsDisplay = true;
    }
}

- (NSColor*)selectionColor
{
    return m_SelectionColor;
}

- (void) setSelectionColor:(NSColor *)selectionColor
{
    if( m_SelectionColor != selectionColor ) {
        m_SelectionColor = selectionColor;
        self.needsDisplay = true;
    }
}

- (NSColor*)cursorColor
{
    return m_CursorColor;
}

- (void)setCursorColor:(NSColor *)cursorColor
{
    if( m_CursorColor != cursorColor ) {
        m_CursorColor = cursorColor;
        self.needsDisplay = true;
    }
}

#define ANSI_COLOR( getter, setter, index ) \
    - (NSColor*)getter \
    {\
        return m_AnsiColors[index];\
    }\
    - (void)setter:(NSColor *)color\
    {\
        if( m_AnsiColors[index] != color ) { \
            m_AnsiColors[index] = color; \
            self.needsDisplay = true; \
        }\
    }

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

@end
