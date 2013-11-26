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
//    return NO;
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
    m_Parser->ProcessKeyDown(event);
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    if(!m_Screen)
        return;
    
    m_Screen->Lock();
    
    // Drawing code here.
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    oms::SetParamsForUserASCIIArt(context, m_FontCache);
    
    oms::SetFillColor(context, DoubleColor(1,1,1,1));

    
    int x = 0, y = 0;
    int lines_no = m_Screen->GetLinesCount();
    
    for(int i = 0; i < lines_no; ++i)
    {
        x = 0;
        auto *line = m_Screen->GetLine(i);
        for(int n = 0; n < line->size(); ++n)
        {
            auto &char_space = (*line)[n];
            int foreground = char_space.foreground;
            if(char_space.intensity) foreground += 8;
            int background = char_space.background;
//            printf("%d", background);
            
            oms::DrawSingleUniCharXY(char_space.l,
                                     x,
                                     y,
                                     context,
                                     m_FontCache,
                                     TermColorToDoubleColor(foreground),
                                     TermColorToDoubleColor(background)
                                     );
            
            if(char_space.underline)
            {
                /* NEED REAL UNDERLINE POSITION HERE !!! */
                CGRect rc;
                rc.origin.x = x * m_FontCache->Width();
                rc.origin.y = y * m_FontCache->Height() + m_FontCache->Height() - 1;
                rc.size.width = m_FontCache->Width();
                rc.size.height = 1;
                CGContextFillRect(context, rc);
                
/*                CGRectMake(_x * _cache->Width(),
                           _y * _cache->Height(),
                           _cache->Width(),
                           _cache->Height()));*/
                
            }
            
            ++x;
        }
        
        
        
        ++y;
    }
    
    
    [self.window setTitle:[NSString stringWithUTF8String:m_Screen->Title()]];
    m_Screen->Unlock();
}

@end
