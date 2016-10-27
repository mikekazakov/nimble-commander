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

@end
