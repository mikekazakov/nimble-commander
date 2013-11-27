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


static const DoubleColor& TermColorToDoubleColor(int _color)
{
    static const DoubleColor colors[16] = {
        {  0./ 255.,   0./ 255.,   0./ 255., 1.}, // Black
        {153./ 255.,   0./ 255.,   0./ 255., 1.}, // Red
        {  0./ 255., 166./ 255.,   0./ 255., 1.}, // Green
        {153./ 255., 153./ 255.,   0./ 255., 1.}, // Yellow
        {  0./ 255.,   0./ 255., 178./ 255., 1.}, // Blue
        {178./ 255.,   0./ 255., 178./ 255., 1.}, // Magenta
        {  0./ 255., 166./ 255., 178./ 255., 1.}, // Cyan
        {191./ 255., 191./ 255., 191./ 255., 1.}, // White
        {102./ 255., 102./ 255., 102./ 255., 1.}, // Bright Black
        {229./ 255.,   0./ 255.,   0./ 255., 1.}, // Bright Red
        {  0./ 255., 217./ 255.,   0./ 255., 1.}, // Bright Green
        {229./ 255., 229./ 255.,   0./ 255., 1.}, // Bright Yellow
        {  0./ 255.,   0./ 255., 255./ 255., 1.}, // Bright Blue
        {229./ 255.,   0./ 255., 229./ 255., 1.}, // Bright Magenta
        {  0./ 255., 229./ 255., 229./ 255., 1.}, // Bright Cyan
        {229./ 255., 229./ 255., 229./ 235., 1.}  // Bright White
    };
    assert(_color >= 0 && _color <= 15);
    return colors[_color];
}

@implementation TermView
{
    int             m_SymbHeight;
    int             m_SymbWidth;
    FontCache      *m_FontCache;
    TermScreen     *m_Screen;
    TermParser     *m_Parser;
//    /*NSScroller*/TermViewScroller     *m_Scroller;
//    int             m_ScrollPos; // zero means that real screen fits view
                                 // any positive values show number of lines that real screen is scrolled down
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        CTFontRef font = CTFontCreateWithName( (CFStringRef) @"Menlo-Regular", 13, 0);
        m_FontCache = FontCache::FontCacheFromFont(font);
        CFRelease(font);
        
        m_SymbHeight = floor(frame.size.height / m_FontCache->Height());
        m_SymbWidth = floor(frame.size.width / m_FontCache->Width());
//        m_ScrollPos = 0;
        
/*        m_Scroller = [[TermViewScroller alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
//        [m_Scroller setWantsLayer:true];
        m_Scroller.knobAlphaValue = 1;
        [m_Scroller setScrollerStyle:NSScrollerStyleOverlay];
        [m_Scroller setEnabled:YES];
        [m_Scroller setTarget:self];
        [m_Scroller setAction:@selector(VerticalScroll:)];
        [m_Scroller setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:m_Scroller];
 
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_Scroller);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_Scroller(15)]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_Scroller]-(==0)-|" options:0 metrics:nil views:views]];
        */
//        [self setWantsLayer:true];
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

- (int) SymbWidth
{
    return m_SymbWidth;
}

- (int) SymbHeight
{
    return m_SymbHeight;
}

- (void) AttachToScreen:(TermScreen*)_scr
{
    m_Screen = _scr;
}

- (void) AttachToParser:(TermParser*)_par
{
    m_Parser = _par;
}

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];
    if ( [character length] == 1 )
    {
        unichar const unicode        = [character characterAtIndex:0];
        NSUInteger mod = [event modifierFlags];
        if(unicode == 'o' &&
           (mod & NSAlternateKeyMask) &&
           (mod & NSCommandKeyMask)
           )
        {
            [self.superview cancelOperation:self];
            return;
        }
    }

    m_Parser->ProcessKeyDown(event);
}

- (void)adjustSizes
{
    double sx = m_Screen->GetWidth() * m_FontCache->Width();
    double sy = (m_Screen->GetHeight() + m_Screen->ScrollBackLinesCount()) * m_FontCache->Height();
    [self setFrame: NSMakeRect(0, 0, sx, sy)];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    if(!m_Screen)
        return;
    
/*    static uint64_t last_redraw = GetTimeInNanoseconds();
    uint64_t now = GetTimeInNanoseconds();
    NSLog(@"%llu", (now - last_redraw)/1000000);
    last_redraw = now;*/
    
//    MachTimeBenchmark tmb;
    
//    NSLog(@"%f - %f", dirtyRect.origin.y, dirtyRect.origin.y + dirtyRect.size.height);
    
    int line_start = floor(dirtyRect.origin.y / m_FontCache->Height());
    int line_end   = line_start +  ceil(dirtyRect.size.height / m_FontCache->Height());
    
    
    m_Screen->Lock();
    
    
    // Drawing code here.
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
//    oms::SetParamsForUserASCIIArt(context, m_FontCache);
    oms::SetParamsForUserReadableText(context, m_FontCache);
    CGContextSetShouldSmoothFonts(context, true);

    
    int y = /*0*/ line_start;
//    int lines_no = m_Screen->GetLinesCount();
    int lines_no = m_Screen->GetHeight();
//    for(int i = 0; i < lines_no; ++i)
    for(int i = line_start; i < line_end; ++i)
    {
        
        if(i < m_Screen->ScrollBackLinesCount())
        {
            // scrollback
            auto *line = m_Screen->GetScrollBackLine(i);
                        if(line)
            [self DrawLine:line at_y:y context:context];
        }
        else
        {
            // real screen
            auto *line = m_Screen->GetScreenLine(i - m_Screen->ScrollBackLinesCount());
            if(line)
                [self DrawLine:line at_y:y context:context];
        }
        
        ++y;
    }
    
    
//    [self.window setTitle:[NSString stringWithUTF8String:m_Screen->Title()]];

    // update scrolling stuff
/*    double prop = 1;
    if( m_Screen->ScrollBackLinesCount() > 0 )
        prop = double(m_Screen->GetHeight()) / double(m_Screen->ScrollBackLinesCount() + m_Screen->GetHeight());
    [m_Scroller setKnobProportion: prop];

    double pos = 1.;
    if(m_ScrollPos > 0)
        pos = double(m_Screen->ScrollBackLinesCount() - m_ScrollPos) /
            double(m_Screen->ScrollBackLinesCount());
    [m_Scroller setDoubleValue:pos];
    */
    
    
    m_Screen->Unlock();
    
//    tmb.Reset("drawn in: ");
    
}

- (void) DrawLine:(const std::vector<TermScreen::Space> *)_line at_y:(int)_y context:(CGContextRef)_context
{
    // draw backgrounds
    DoubleColor curr_c = {-1, -1, -1, -1};
    int x = 0;
    for(int n = 0; n < _line->size(); ++n)
    {
        TermScreen::Space char_space = (*_line)[n];
        const DoubleColor &c = TermColorToDoubleColor(char_space.background);
        if(c != curr_c)
            oms::SetFillColor(_context, curr_c = c);
        
        CGContextFillRect(_context,
                          CGRectMake(x * m_FontCache->Width(),
                                     _y * m_FontCache->Height(),
                                     m_FontCache->Width(),
                                     m_FontCache->Height()));
        ++x;
    }
    
    // draw glyphs
    x = 0;
    curr_c = {-1, -1, -1, -1};
    for(int n = 0; n < _line->size(); ++n)
    {
        TermScreen::Space char_space = (*_line)[n];
        int foreground = char_space.foreground;
        if(char_space.intensity)
            foreground += 8;
        
        if(char_space.l != 0 && char_space.l != 32)
        {
            const DoubleColor &c = TermColorToDoubleColor(foreground);
            if(c != curr_c)
                oms::SetFillColor(_context, curr_c = c);
            
            oms::DrawSingleUniCharXY(char_space.l, x, _y, _context, m_FontCache);
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

- (void)VerticalScroll:(id)sender
{
/*    switch ([m_Scroller hitPart])
    {
        case NSScrollerKnob:
            // This case is when the knob itself is pressed
//            [m_ViewImpl HandleVerticalScroll:[m_VerticalScroller doubleValue]];
            {
//                double full_sz = m_Screen->GetHeight() + m_Screen->ScrollBackLinesCount();
                double off = [m_Scroller doubleValue] * double(m_Screen->ScrollBackLinesCount());
                m_ScrollPos = m_Screen->ScrollBackLinesCount() - floor(off);
                [self setNeedsDisplay:true];
                break;
            }
    } */
    
/*    double full_document_size = double(m_Lines.size()) * m_FontHeight;
    double scroll_y_offset = _pos * (full_document_size - m_FrameSize.height);
    m_VerticalOffset = floor(scroll_y_offset / m_FontHeight);
    m_SmoothOffset.y = scroll_y_offset - m_VerticalOffset * m_FontHeight;
    [m_View setNeedsDisplay:true];*/
}

- (void)scrollWheel1:(NSEvent *)theEvent
{
    double delta_y = [theEvent scrollingDeltaY];
//    double delta_x = [theEvent scrollingDeltaX];
//    if(![theEvent hasPreciseScrollingDeltas])
//    {
/*    if(delta_y < 0)
    {
        if(m_ScrollPos > 0)
            m_ScrollPos--;
            
        
        
    }
    else if(delta_y > 0)
    {
        if(m_ScrollPos < m_Screen->ScrollBackLinesCount())
            m_ScrollPos++;
        
    }
    [self setNeedsDisplay:true];*/
}

@end
