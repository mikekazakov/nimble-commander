// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
        
        if( [self respondsToSelector:@selector(setBackgroundViewScrollsWithContent:)] ) {
            self.backgroundViewScrollsWithContent = true;
        }
       [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];
    }
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (BOOL)isOpaque
{
    return true;
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

- (BOOL)acceptsFirstMouse:(nullable NSEvent *)event
{
    return false;
}

- (void)mouseDown:(NSEvent *)event
{
    [self.panelView panelItem:-1 mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
}

static NSEvent *SwapScrollAxis( NSEvent *_event )
{
    const auto cg_event = CGEventCreateCopy(_event.CGEvent);
    if( !cg_event )
        return nil;
    
    CGEventSetDoubleValueField(cg_event, kCGScrollWheelEventFixedPtDeltaAxis2, _event.deltaY);
    CGEventSetDoubleValueField(cg_event, kCGScrollWheelEventFixedPtDeltaAxis1, 0.0);
    
    const auto new_event = [NSEvent eventWithCGEvent:cg_event];
    CFRelease(cg_event);

    return new_event;
}

- (void)scrollWheel:(NSEvent *)event
{
    if(event.phase == NSEventPhaseNone &&
       event.momentumPhase == NSEventPhaseNone &&
       event.hasPreciseScrollingDeltas == false &&
       event.deltaX == 0.0 &&
       event.deltaY != 0.0 ) {
       // for vertical scroll coming from USB PC mice we swap the scroll asix, so user
       // can use mouse wheel without holding a Shift button
       if( auto new_event = SwapScrollAxis(event) )
           [super scrollWheel:new_event];
        return;
    }

    [super scrollWheel:event];
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

- (void)prepareContentInRect:(NSRect)rect
{
    // Disabling the responsive scrolling/prefetching for now on 10.13+.
    // It destroys the loading time, need to fix it later somehow
    // https://developer.apple.com/library/content/releasenotes/AppKit/RN-AppKit/
    [super prepareContentInRect:self.visibleRect];
}

@end
