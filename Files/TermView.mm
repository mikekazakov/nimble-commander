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
    FontCache      *m_FontCache;
    int m_SymbHeight;
    int m_SymbWidth;
    TermScreen* m_Screen;
    TermParser* m_Parser;
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
/*    NSLog(@"!");
    NSString*  const character = [event charactersIgnoringModifiers];
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
    */
    
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
    
    m_Screen->Lock();
    
    // Drawing code here.
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
//    oms::SetParamsForUserASCIIArt(context, m_FontCache);
    oms::SetParamsForUserReadableText(context, m_FontCache);
    CGContextSetShouldSmoothFonts(context, true);
    
//    oms::SetFillColor(context, DoubleColor(1,1,1,1));

    
    int x = 0, y = 0;
    int lines_no = m_Screen->GetLinesCount();
    
    for(int i = 0; i < lines_no; ++i)
    {

        auto *line = m_Screen->GetLine(i);
        
        
        
        // draw backgrounds
        DoubleColor curr_c = {-1, -1, -1, -1};
        x = 0;
        for(int n = 0; n < line->size(); ++n)
        {
            TermScreen::Space char_space = (*line)[n];
//            int foreground = char_space.foreground;
//            if(char_space.intensity) foreground += 8;
            const DoubleColor &c = TermColorToDoubleColor(char_space.background);
            if(c != curr_c)
                oms::SetFillColor(context, curr_c = c);

            CGContextFillRect(context,
                              CGRectMake(x * m_FontCache->Width(),
                                         y * m_FontCache->Height(),
                                         m_FontCache->Width(),
                                         m_FontCache->Height()));
            ++x;
        }
        
        // draw glyphs
        x = 0;
        curr_c = {-1, -1, -1, -1};
        for(int n = 0; n < line->size(); ++n)
        {
            TermScreen::Space char_space = (*line)[n];
            int foreground = char_space.foreground;
            if(char_space.intensity) foreground += 8;
//            int background = char_space.background;
//            printf("%d", background);
            
            if(char_space.l != 0 && char_space.l != 32)
            {
                const DoubleColor &c = TermColorToDoubleColor(foreground);
                if(c != curr_c)
                    oms::SetFillColor(context, curr_c = c);
                
                oms::DrawSingleUniCharXY(char_space.l, x, y, context, m_FontCache);
            }
            
            if(char_space.underline)
            {
                /* NEED REAL UNDERLINE POSITION HERE !!! */
                // need to set color here?
                CGRect rc;
                rc.origin.x = x * m_FontCache->Width();
                rc.origin.y = y * m_FontCache->Height() + m_FontCache->Height() - 1;
                rc.size.width = m_FontCache->Width();
                rc.size.height = 1;
                CGContextFillRect(context, rc);
            }
            
            ++x;
        }
        
        ++y;
    }
    
    
//    [self.window setTitle:[NSString stringWithUTF8String:m_Screen->Title()]];
    m_Screen->Unlock();
    
//    tmb.Reset("drawn in: ");
}

@end
