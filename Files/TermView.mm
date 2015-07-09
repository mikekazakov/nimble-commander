//
//  TermView.m
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "TermView.h"
#import "OrthodoxMonospace.h"
#import "FontCache.h"
#import "TermScreen.h"
#import "TermParser.h"
#import "Common.h"
#import "NSUserDefaults+myColorSupport.h"

struct SelPoint
{
    int x;
    int y;
    inline bool operator > (const SelPoint&_r) const { return (y > _r.y) || (y == _r.y && x >  _r.x); }
    inline bool operator >=(const SelPoint&_r) const { return (y > _r.y) || (y == _r.y && x >= _r.x); }
    inline bool operator < (const SelPoint&_r) const { return !(*this >= _r); }
    inline bool operator <=(const SelPoint&_r) const { return !(*this >  _r); }
    inline bool operator ==(const SelPoint&_r) const { return y == _r.y && x == _r.x; }
    inline bool operator !=(const SelPoint&_r) const { return y != _r.y || x != _r.x; }
};

struct AnsiColors : array<DoubleColor, 16>
{
    AnsiColors() : array{{
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor0"], // Black
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor1"], // Red
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor2"], // Green
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor3"], // Yellow
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor4"], // Blue
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor5"], // Magenta
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor6"], // Cyan
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor7"], // White
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor8"], // Bright Black
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor9"], // Bright Red
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor10"],// Bright Green
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor11"],// Bright Yellow
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor12"],// Bright Blue
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor13"],// Bright Magenta
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor14"],// Bright Cyan
            [NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.AnsiColor15"] // Bright White
    }}{}
};

static inline bool IsBoxDrawingCharacter(uint32_t _ch)
{
    return _ch >= 0x2500 && _ch <= 0x257F;
}

@implementation TermView
{
    shared_ptr<FontCache> m_FontCache;
    TermScreen     *m_Screen;
    TermParser     *m_Parser;
    
    int             m_LastScreenFSY;
    
    bool            m_HasSelection;
    SelPoint        m_SelStart;
    SelPoint        m_SelEnd;
    AnsiColors      m_AnsiColors;
    DoubleColor     m_ForegroundColor;
    DoubleColor     m_BoldForegroundColor;
    DoubleColor     m_BackgroundColor;
    DoubleColor     m_SelectionColor;
    DoubleColor     m_CursorColor;
    TermViewCursor  m_CursorType;
    FPSLimitedDrawer *m_FPS;
    NSSize          m_IntrinsicSize;
}

@synthesize FPSDrawer = m_FPS;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_LastScreenFSY = 0;
        m_HasSelection = false;
        m_FPS = [[FPSLimitedDrawer alloc] initWithView:self];
        m_FPS.fps = [[NSUserDefaults.standardUserDefaults valueForKeyPath:@"Terminal.FramesPerSecond"] intValue];
        m_IntrinsicSize = NSMakeSize(NSViewNoInstrinsicMetric, frame.size.height);
        [self reloadSettings];
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

-(BOOL) isOpaque
{
	return YES;
}

- (void)resetCursorRects
{
    [self addCursorRect:self.frame cursor:[NSCursor IBeamCursor]];
}

- (TermParser *)parser
{
    return m_Parser;
}

- (const FontCache&) fontCache
{
    return *m_FontCache;
}

- (void) AttachToScreen:(TermScreen*)_scr
{
    m_Screen = _scr;
}

- (void) AttachToParser:(TermParser*)_par
{
    m_Parser = _par;
}

- (void) reloadSettings
{
    NSFont *font = [NSUserDefaults.standardUserDefaults fontForKeyPath:@"Terminal.Font"];
    if(!font)
        font = [NSFont fontWithName:@"Menlo-Regular" size:13];
    m_FontCache = FontCache::FontCacheFromFont((__bridge CTFontRef)font);
    
    m_ForegroundColor = DoubleColor([NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.FgColor"]);
    m_BoldForegroundColor = DoubleColor([NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.BldFgColor"]);
    m_BackgroundColor = DoubleColor([NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.BgColor"]);
    m_SelectionColor = DoubleColor([NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.SelColor"]);
    m_CursorColor = DoubleColor([NSUserDefaults.standardUserDefaults colorForKeyPath:@"Terminal.CursorColor"]);
    m_CursorType = (TermViewCursor)[[NSUserDefaults.standardUserDefaults valueForKeyPath:@"Terminal.CursorMode"] intValue];
    m_AnsiColors = AnsiColors();
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

- (void)adjustSizes:(bool)_mandatory
{
    int fsy = m_Screen->Height() + m_Screen->Buffer().BackScreenLines();
    if(fsy == m_LastScreenFSY && _mandatory == false)
        return;
    
    double sy = fsy * m_FontCache->Height();
    double rest = self.superview.frame.size.height -
        floor(self.superview.frame.size.height / m_FontCache->Height()) * m_FontCache->Height();

    m_IntrinsicSize = NSMakeSize(NSViewNoInstrinsicMetric, sy + rest);
    [self invalidateIntrinsicContentSize];
    [self.enclosingScrollView layoutSubtreeIfNeeded];
    
    
    [self scrollToBottom];
}

- (void) scrollToBottom
{
    
    auto clipview = (NSClipView*)self.superview;
    auto scrollview = self.enclosingScrollView;
    
    auto p = NSMakePoint(0, self.frame.size.height - scrollview.contentSize.height);

    [clipview scrollToPoint:p];
    [scrollview reflectScrolledClipView:clipview];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    // Drawing code here.
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    oms::SetFillColor(context, m_BackgroundColor);
    CGContextFillRect(context, NSRectToCGRect(self.bounds));
    
    if(!m_Screen)
        return;
    
/*    static uint64_t last_redraw = GetTimeInNanoseconds();
    uint64_t now = GetTimeInNanoseconds();
    NSLog(@"%llu", (now - last_redraw)/1000000);
    last_redraw = now;*/
    
//    MachTimeBenchmark tmb;
    
    int line_start = floor([self.superview bounds].origin.y / m_FontCache->Height());
    int line_end   = line_start + ceil(NSHeight(self.superview.bounds) / m_FontCache->Height());
    
    m_Screen->Lock();
    
//    oms::SetParamsForUserASCIIArt(context, m_FontCache);
    oms::SetParamsForUserReadableText(context, m_FontCache.get());
    CGContextSetShouldSmoothFonts(context, true);

    for(int i = line_start, bsl = m_Screen->Buffer().BackScreenLines();
        i < line_end;
        ++i)
    {
        if(i < bsl)
        {
            // scrollback
//            auto line = m_Screen->GetScrollBackLine(i);
            auto line = m_Screen->Buffer().LineFromNo(i - bsl);
            if(line.first)
                [self DrawLine:line
                          at_y:i
                         sel_y:i - bsl
                       context:context
                     cursor_at:-1];
        }
        else
        {
            // real screen
//            auto line = m_Screen->GetScreenLine(i - m_Screen->ScrollBackLinesCount());
            auto line = m_Screen->Buffer().LineFromNo(i - bsl);
            if(line.first)
            {
                if(m_Screen->CursorY() != i - bsl)
                    [self DrawLine:line
                              at_y:i
                             sel_y:i - bsl
                           context:context
                         cursor_at:-1];
                else
                    [self DrawLine:line
                              at_y:i
                             sel_y:i -
                     
                     bsl
                           context:context
                         cursor_at:m_Screen->CursorX()];
            }
        }
    }
    
    m_Screen->Unlock();
    
//    tmb.Reset("drawn in: ");
    
}

- (void) DrawLine:(pair<const TermScreen::Space*, const TermScreen::Space*>)_line
             at_y:(int)_y
            sel_y:(int)_sel_y
          context:(CGContextRef)_context
        cursor_at:(int)_cur_x
{
    // draw backgrounds
    DoubleColor curr_c = {-1, -1, -1, -1};
    int x = 0;
//    for(TermScreen::Space char_space: _line.chars)
    for(auto char_space: _line)
    {
        int bg_no = char_space.reverse ? char_space.foreground : char_space.background;
        if(bg_no != TermScreenColors::Default) {
            const DoubleColor &c = m_AnsiColors[bg_no];
            if(c != m_BackgroundColor) {
                if(c != curr_c)
                    oms::SetFillColor(_context, curr_c = c);
        
                CGContextFillRect(_context,
                                  CGRectMake(x * m_FontCache->Width(),
                                             _y * m_FontCache->Height(),
                                             m_FontCache->Width(),
                                             m_FontCache->Height()));
            }
        }
        ++x;
    }
    
    // draw selection if it's here
    if(m_HasSelection)
    {
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
        
        if(rc.origin.x >= 0)
        {
            oms::SetFillColor(_context, m_SelectionColor);
            CGContextFillRect(_context, rc);
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
    curr_c = {-1, -1, -1, -1};
    bool is_aa = true;
    CGContextSetShouldAntialias(_context, is_aa);
    
//    for(TermScreen::Space char_space: _line.chars)
    for(auto char_space: _line)
    {
        DoubleColor c = m_ForegroundColor;
        if(char_space.reverse) {
            c = char_space.background != TermScreenColors::Default ?
                m_AnsiColors[char_space.background] :
                m_BackgroundColor;
        } else {
            int foreground = char_space.foreground;
            if(foreground != TermScreenColors::Default){
                if(char_space.intensity)
                    foreground += 8;
                c = m_AnsiColors[foreground];
            } else {
                if(char_space.intensity)
                    c = m_BoldForegroundColor;
            }
        }
        
        if(char_space.l != 0 &&
           char_space.l != 32 &&
           char_space.l != TermScreen::MultiCellGlyph
           )
        {
            if(c != curr_c)
                oms::SetFillColor(_context, curr_c = c);
            
            bool should_aa = !IsBoxDrawingCharacter(char_space.l);
            if(should_aa != is_aa)
                CGContextSetShouldAntialias(_context, is_aa = should_aa);
            
            oms::DrawSingleUniCharXY(char_space.l, x, _y, _context, m_FontCache.get());
            
            if(char_space.c1 != 0)
                oms::DrawSingleUniCharXY(char_space.c1, x, _y, _context, m_FontCache.get());
            if(char_space.c2 != 0)
                oms::DrawSingleUniCharXY(char_space.c2, x, _y, _context, m_FontCache.get());
        }        
        
        if(char_space.underline)
        {
            /* NEED REAL UNDERLINE POSITION HERE !!! */
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
    oms::SetFillColor(_context, m_CursorColor);
    
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

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    proposedVisibleRect.origin.y = (int)(proposedVisibleRect.origin.y/m_FontCache->Height() + 0.5) * m_FontCache->Height();
    return proposedVisibleRect;
}

/**
 * return predicted character position regarding current font setup
 * y values [0...+y should be treated as rows in real terminal screen
 * y values -y...0) should be treated as rows in backscroll. y=-1 mean the closes to real screen row
 * x values are trivial - float x position divided by font's width
 * returned points may not correlate with real lines' lengths or scroll sizes, so they need to be treated carefully
 */
- (SelPoint)ProjectPoint:(NSPoint)_point
{
    int line_predict = floor(_point.y / m_FontCache->Height()) - m_Screen->Buffer().BackScreenLines();
    int col_predict = floor(_point.x / m_FontCache->Width());
    return SelPoint{col_predict, line_predict};
}

- (void) mouseDown:(NSEvent *)_event
{

//    NSPoint pt = [m_View convertPoint:[event locationInWindow] fromView:nil];
//    [self ProjectPoint:[self convertPoint:[_event locationInWindow] fromView:nil]];
    [self HandleSelectionWithMouseDragging:_event];
}

- (void) HandleSelectionWithMouseDragging: (NSEvent*) event
{
    // TODO: not a precise selection modification. look at viewer, it has better implementation.
    
    bool modifying_existing_selection = ([event modifierFlags] & NSShiftKeyMask) ? true : false;
    NSPoint first_loc = [self convertPoint:[event locationInWindow] fromView:nil];
    
    while ([event type]!=NSLeftMouseUp)
    {
        NSPoint curr_loc = [self convertPoint:[event locationInWindow] fromView:nil];
        
        SelPoint start = [self ProjectPoint:first_loc];
        SelPoint end   = [self ProjectPoint:curr_loc];
        
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
    
    vector<uint32_t> unichars;
    SelPoint curr = m_SelStart;
    while(true)
    {
        if(curr >= m_SelEnd) break;
        
        auto line = m_Screen->Buffer().LineFromNo( curr.y );
        
        if( !line.first ) {
            curr.y++;
            continue;
        }
        
        bool any_inserted = false;
        auto chars_len = line.second - line.first;
        for(; curr.x < chars_len && ( (curr.y == m_SelEnd.y) ? (curr.x < m_SelEnd.x) : true); ++curr.x) {
            auto &sp = line.first[curr.x];
            if(sp.l == TermScreen::MultiCellGlyph) continue;
            unichars.push_back(sp.l != 0 ? sp.l : ' ');
            if(sp.c1 != 0) unichars.push_back(sp.c1);
            if(sp.c2 != 0) unichars.push_back(sp.c2);
            any_inserted = true;
        }
    
        if(curr >= m_SelEnd)
            break;
        
        if(any_inserted && !m_Screen->Buffer().LineWrapped( curr.y ))
            unichars.push_back(0x000A);
        
        curr.y++;
        curr.x = 0;
    }
    
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


@end
