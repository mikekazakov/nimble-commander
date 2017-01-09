#include <NimbleCommander/Core/Theming/Theme.h>
#include "../PanelView.h"
#include "PanelBriefViewCollectionView.h"

@implementation PanelBriefViewCollectionView
{
    bool m_IsDropTarget;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.selectable = true;
       [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];
    }
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (PanelView*)panelView
{
    NSView *sv = self.superview;
    while( sv != nil && objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    return (PanelView*)sv;
}

- (void)keyDown:(NSEvent *)event
{
    if( auto pv = self.panelView )
        [pv keyDown:event];
}

- (void)mouseDown:(NSEvent *)event
{
}

- (void)mouseUp:(NSEvent *)event
{
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    auto op = [self.panelView panelItem:-1 operationForDragging:sender];
    if( op != NSDragOperationNone ) {
        self.isDropTarget = true;
    }
    return op;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    self.isDropTarget = false;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    // possibly add some checking stage here later
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    if( self.isDropTarget ) {
        self.isDropTarget = false;
        return [self.panelView panelItem:-1 performDragOperation:sender];
    }
    else
        return false;
}

- (bool) isDropTarget
{
    return m_IsDropTarget;
}

- (void) setIsDropTarget:(bool)isDropTarget
{
    if( m_IsDropTarget != isDropTarget ) {
        m_IsDropTarget = isDropTarget;
        if( m_IsDropTarget ) {
            self.layer.borderWidth = 1;
            self.layer.borderColor = CurrentTheme().FilePanelsGeneralDropBorderColor().CGColor;
        }
        else
            self.layer.borderWidth = 0;
    }
}

@end
