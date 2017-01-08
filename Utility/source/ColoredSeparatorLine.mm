#include <Utility/ColoredSeparatorLine.h>

@implementation ColoredSeparatorLine

- (void)drawRect:(NSRect)rect
{
    if( self.borderColor ) {
        const auto b = self.bounds;
        const auto rc = b.size.width > b.size.height ?
            NSMakeRect(0, floor(b.size.height / 2), b.size.width, 1) :
            NSMakeRect( floor(b.size.width / 2), 0, 1, b.size.height);
        
        [self.borderColor set];        
        if( self.borderColor.alphaComponent == 1. )
            NSRectFill(rc);
        else
            NSRectFillUsingOperation(rc, NSCompositingOperationSourceAtop);
    }
    else
        [super drawRect:rect];
}

@end
