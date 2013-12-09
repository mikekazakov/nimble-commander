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

static const DoubleColor g_BackgroundColor = {0., 0., 0., 1.};

static inline bool IsBoxDrawingCharacter(unsigned short _ch)
{
    return _ch >= 0x2500 && _ch <= 0x257F;
}

@implementation TermView
{
    FontCache      *m_FontCache;
    TermScreen     *m_Screen;
    TermParser     *m_Parser;
    
    int             m_LastScreenFSY;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        CTFontRef font = CTFontCreateWithName( (CFStringRef) @"Menlo-Regular", 13, 0);
        m_FontCache = FontCache::FontCacheFromFont(font);
        CFRelease(font);
        m_LastScreenFSY = 0;
    }
    return self;
}

-(void) dealloc
{
    FontCache::ReleaseCache(m_FontCache);
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

- (FontCache*) FontCache
{
    return m_FontCache;
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
            [self.superview.superview cancelOperation:self];
            return;
        }
    }

    m_Parser->ProcessKeyDown(event);
    [self scrollToBottom];
}

- (void)adjustSizes:(bool)_mandatory
{
    int fsy = m_Screen->Height() + m_Screen->ScrollBackLinesCount();
    if(fsy == m_LastScreenFSY && _mandatory == false)
        return;
    
    m_LastScreenFSY = fsy;
    
    double sx = self.frame.size.width;
    double sy = fsy * m_FontCache->Height();
    
    double rest = [self.superview frame].size.height -
        floor([self.superview frame].size.height / m_FontCache->Height()) * m_FontCache->Height();
    
    [self setFrame: NSMakeRect(0, 0, sx, sy + rest)];
    
    [self scrollToBottom];
}

- (void) scrollToBottom
{
    [((NSClipView*)self.superview) scrollToPoint:NSMakePoint(0,
                                              self.frame.size.height - ((NSScrollView*)self.superview.superview).contentSize.height)];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    // Drawing code here.
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    oms::SetFillColor(context, g_BackgroundColor);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    
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
    oms::SetParamsForUserReadableText(context, m_FontCache);
    CGContextSetShouldSmoothFonts(context, true);

    for(int i = line_start; i < line_end; ++i)
    {
        
        if(i < m_Screen->ScrollBackLinesCount())
        {
            // scrollback
            auto *line = m_Screen->GetScrollBackLine(i);
            if(line)
                [self DrawLine:line at_y:i context:context cursor_at:-1];
        }
        else
        {
            // real screen
            auto *line = m_Screen->GetScreenLine(i - m_Screen->ScrollBackLinesCount());
            if(line)
            {
                if(m_Screen->CursorY() != i - m_Screen->ScrollBackLinesCount())
                    [self DrawLine:line at_y:i context:context cursor_at:-1];
                else
                    [self DrawLine:line at_y:i context:context cursor_at:m_Screen->CursorX()];
            }
        }
    }
    
    m_Screen->Unlock();
    
//    tmb.Reset("drawn in: ");
    
}

- (void) DrawLine:(const std::vector<TermScreen::Space> *)_line
             at_y:(int)_y
          context:(CGContextRef)_context
        cursor_at:(int)_cur_x
{
    // draw backgrounds
    DoubleColor curr_c = {-1, -1, -1, -1};
    int x = 0;
    for(int n = 0; n < _line->size(); ++n)
    {
        TermScreen::Space char_space = (*_line)[n];
        const DoubleColor &c = TermColorToDoubleColor(char_space.reverse ? char_space.foreground : char_space.background);
        if(c != g_BackgroundColor)
        {
            if(c != curr_c)
                oms::SetFillColor(_context, curr_c = c);
        
            CGContextFillRect(_context,
                            CGRectMake(x * m_FontCache->Width(),
                                        _y * m_FontCache->Height(),
                                        m_FontCache->Width(),
                                        m_FontCache->Height()));
        }
        ++x;
    }
    
    // draw cursor if it's here
    if(_cur_x >= 0)
    {
        CGContextSetRGBFillColor(_context, 0.4, 0.4, 0.4, 1.);
        CGContextFillRect(_context,
                        CGRectMake(_cur_x * m_FontCache->Width(),
                                    _y * m_FontCache->Height(),
                                    m_FontCache->Width(),
                                    m_FontCache->Height()));
    }
    
    // draw glyphs
    x = 0;
    curr_c = {-1, -1, -1, -1};
    bool is_aa = true;
    CGContextSetShouldAntialias(_context, is_aa);
    
    for(int n = 0; n < _line->size(); ++n)
    {
        TermScreen::Space char_space = (*_line)[n];
        int foreground = char_space.foreground;
        if(char_space.intensity)
            foreground += 8;
        
        if(char_space.l != 0 &&
           char_space.l != 32 &&
           char_space.l != TermScreen::MultiCellGlyph
           )
        {
            const DoubleColor &c = TermColorToDoubleColor(char_space.reverse ? char_space.background : foreground);
            if(c != curr_c)
                oms::SetFillColor(_context, curr_c = c);
            
            bool should_aa = !IsBoxDrawingCharacter(char_space.l);
            if(should_aa != is_aa)
                CGContextSetShouldAntialias(_context, is_aa = should_aa);
            
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

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    proposedVisibleRect.origin.y = (int)(proposedVisibleRect.origin.y/m_FontCache->Height() + 0.5) * m_FontCache->Height();
    return proposedVisibleRect;
}

@end
