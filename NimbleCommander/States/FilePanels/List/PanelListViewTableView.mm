#include "../../../Files/PanelView.h"
#include "PanelListViewTableView.h"

@implementation PanelListViewTableView

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (void)keyDown:(NSEvent *)event
{
    NSView *sv = self.superview;
    while( sv != nil && objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    
    if( auto pv = objc_cast<PanelView>(sv) )
        [pv keyDown:event];
}

- (void)mouseDown:(NSEvent *)event
{
}

- (void)mouseUp:(NSEvent *)event
{
}

//- (void)drawBackgroundInClipRect:(NSRect)clipRect
//{
//    
//    
//}

//- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {}
//- (void)highlightSelectionInClipRect:(NSRect)clipRect {}
//- (void)drawGridInClipRect:(NSRect)clipRect {}
//- (void)drawBackgroundInClipRect:(NSRect)clipRect {}
//
//
//- (void)display{}
//- (void)displayIfNeeded{}
//- (void)displayIfNeededIgnoringOpacity{}
//- (void)displayRect:(NSRect)rect{}
//- (void)displayIfNeededInRect:(NSRect)rect{}
//- (void)displayRectIgnoringOpacity:(NSRect)rect{}
//- (void)displayIfNeededInRectIgnoringOpacity:(NSRect)rect{}
//- (void)drawRect:(NSRect)dirtyRect{}
//- (void)displayRectIgnoringOpacity:(NSRect)rect inContext:(NSGraphicsContext *)context{}


@end
