// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ColoredSeparatorLine.h>

@implementation ColoredSeparatorLine

- (void)drawRect:(NSRect)rect
{
    auto c = self.borderColor;
    if( c ) {
        const auto b = self.bounds;
        const auto rc = b.size.width > b.size.height ?
            NSMakeRect(0, floor(b.size.height / 2), b.size.width, 1) :
            NSMakeRect( floor(b.size.width / 2), 0, 1, b.size.height);
        
        [c set];
        if( c.alphaComponent == 1. )
            NSRectFill(rc);
        else
            NSRectFillUsingOperation(rc, NSCompositingOperationSourceOver);
    }
    else
        [super drawRect:rect];
}

@end
