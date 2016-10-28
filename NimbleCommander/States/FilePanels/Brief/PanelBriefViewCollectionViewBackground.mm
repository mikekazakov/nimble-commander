#include "PanelBriefViewCollectionViewBackground.h"

@implementation PanelBriefViewCollectionViewBackground
{
    NSColor    *m_RegularColor;
    NSColor    *m_AlternateColor;
    int         m_RowHeight;
}

@synthesize regularColor = m_RegularColor;
@synthesize alternateColor = m_AlternateColor;
@synthesize rowHeight = m_RowHeight;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_RowHeight = 20;
        m_RegularColor = NSColor.controlAlternatingRowBackgroundColors[0];
        m_AlternateColor = NSColor.controlAlternatingRowBackgroundColors[1];
//        self.wantsLayer = true;
    }
    return self;
}

- (BOOL) isFlipped
{
    return true;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (void)drawRect:(NSRect)dirtyRect
{
//    auto aa = [self layer];
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
//
//    CGContextSetFillColorWithColor(context, NSColor.yellowColor.CGColor);
//    CGContextFillRect(context,
////                      NSRectToCGRect(dirtyRect)
//                      NSRectToCGRect(self.bounds)
//                      );
//
    
    for( int y = dirtyRect.origin.y; y < (int)(dirtyRect.origin.y + dirtyRect.size.height); y += m_RowHeight - ( y % m_RowHeight ) ) {
        CGContextSetFillColorWithColor(context, (y / m_RowHeight) % 2 ? m_AlternateColor.CGColor : m_RegularColor.CGColor);
        CGContextFillRect(context,
                          CGRectMake(dirtyRect.origin.x, y, dirtyRect.size.width, m_RowHeight)
                          );
    }
}

- (void) setRowHeight:(int)rowHeight
{
    if( rowHeight != m_RowHeight ) {
        m_RowHeight = rowHeight;
        [self setNeedsLayout:true];
    }
}

- (void) setRegularColor:(NSColor *)regularColor
{
    if( regularColor != m_RegularColor ) {
        m_RegularColor = regularColor;
        [self setNeedsLayout:true];
    }
}

- (void) setAlternateColor:(NSColor *)alternateColor
{
    if( alternateColor != m_AlternateColor ) {
        m_AlternateColor = alternateColor;
        [self setNeedsLayout:true];
    }
}

@end
