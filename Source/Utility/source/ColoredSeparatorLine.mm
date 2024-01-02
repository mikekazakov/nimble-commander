// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ColoredSeparatorLine.h>

@implementation ColoredSeparatorLine
{
    NSColor *m_Color;
}

- (void)drawRect:(NSRect)rect
{
    if( m_Color ) {
        const auto b = self.bounds;
        const auto rc = b.size.width > b.size.height ?
            NSMakeRect(0, floor(b.size.height / 2), b.size.width, 1) :
            NSMakeRect( floor(b.size.width / 2), 0, 1, b.size.height);
        [m_Color set];
        if( m_Color.alphaComponent == 1. )
            NSRectFill(rc);
        else
            NSRectFillUsingOperation(rc, NSCompositingOperationSourceOver);
    }
    else
        [super drawRect:rect];
}

- (void) setBorderColor:(NSColor *)borderColor
{
    if( m_Color == borderColor )
        return;
    m_Color = borderColor;
    [self setNeedsDisplay:true];
}

- (NSColor*)borderColor
{
    return m_Color;
}

@end
