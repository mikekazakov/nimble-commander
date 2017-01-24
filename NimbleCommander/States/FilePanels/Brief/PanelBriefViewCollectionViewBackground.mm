#include <NimbleCommander/Core/Theming/Theme.h>
#include "PanelBriefViewCollectionViewBackground.h"

@implementation PanelBriefViewCollectionViewBackground
{
    int         m_RowHeight;
}

@synthesize rowHeight = m_RowHeight;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_RowHeight = 20;
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
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    
    for( int y = dirtyRect.origin.y; y < (int)(dirtyRect.origin.y + dirtyRect.size.height); y += m_RowHeight - ( y % m_RowHeight ) ) {
        auto c = (y / m_RowHeight) % 2 ?
            CurrentTheme().FilePanelsBriefRegularOddRowBackgroundColor() :
            CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor();
        CGContextSetFillColorWithColor(context, c.CGColor);
        CGContextFillRect(context,
                          CGRectMake(dirtyRect.origin.x, y, dirtyRect.size.width, m_RowHeight)
                          );
    }
}

- (void) setRowHeight:(int)rowHeight
{
    if( rowHeight != m_RowHeight ) {
        m_RowHeight = rowHeight;
        [self setNeedsDisplay:true];
    }
}

@end
