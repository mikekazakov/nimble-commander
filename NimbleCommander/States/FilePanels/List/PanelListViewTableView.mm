#include "../PanelView.h"
#include "PanelListViewTableView.h"

@interface PanelListViewTableView()

@property (nonatomic) bool isDropTarget;

@end

@implementation PanelListViewTableView
{
    bool m_IsDropTarget;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
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
            self.layer.borderColor = NSColor.blueColor.CGColor;
        }
        else
            self.layer.borderWidth = 0;
    }
}

@end
