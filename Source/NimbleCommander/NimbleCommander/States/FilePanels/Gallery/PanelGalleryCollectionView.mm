// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionView.h"
#include "../PanelView.h"
#include <Utility/ObjCpp.h>

@implementation NCPanelGalleryViewCollectionView {
    bool m_SmoothScrolling;
}

@synthesize smoothScrolling = m_SmoothScrolling;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.selectable = true;
        self.backgroundViewScrollsWithContent = true;
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

- (void)ensureItemIsVisible:(int)_item_index
{
    if( _item_index < 0 )
        return;

    NSScrollView *scroll_view = [self enclosingScrollView];
    assert(scroll_view);

    // the existing scroll state and item's position
    const NSRect visible_rect = scroll_view.documentVisibleRect;
    const NSRect item_rect = [self frameForItemAtIndex:_item_index];

    // check if the item is already visible - nothing to do in that case
    if( NSContainsRect(visible_rect, item_rect) )
        return;

    auto scroll_to = [&](NSPoint _pt) {
        if( m_SmoothScrolling ) {
            [scroll_view.contentView scrollPoint:_pt];
        }
        else {
            [scroll_view.contentView setBoundsOrigin:_pt];
        }
        [self prepareContentInRect:NSMakeRect(_pt.x, _pt.y, visible_rect.size.width, visible_rect.size.height)];
    };

    // NB! scrollToItemsAtIndexPaths is NOT used here because at some version of macOS it decided to
    // add gaps to the items it's been asked to scroll to. That looks very buggy. Hence this custom
    // logic
    if( visible_rect.size.width >= item_rect.size.width ) {
        // normal case - scroll to the item, aligning depending on its location
        if( item_rect.origin.x < visible_rect.origin.x ) {
            // align left
            scroll_to(NSMakePoint(item_rect.origin.x, 0.));
        }
        else if( NSMaxX(item_rect) > NSMaxX(visible_rect) ) {
            // align right
            scroll_to(NSMakePoint(item_rect.origin.x + item_rect.size.width - visible_rect.size.width, 0.));
        }
        else {
            // center
            scroll_to(NSMakePoint(item_rect.origin.x - ((visible_rect.size.width - item_rect.size.width) / 2.), 0.));
        }
    }
    else {
        // singular case - just try to show as much as possible
        scroll_to(NSMakePoint(item_rect.origin.x, 0.));
    }
}

- (PanelView *)panelView
{
    NSView *sv = self.superview;
    while( sv != nil && nc::objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    return static_cast<PanelView *>(sv);
}

- (void)keyDown:(NSEvent *)event
{
    if( auto pv = self.panelView )
        [pv keyDown:event];
}

- (BOOL)acceptsFirstMouse:(nullable NSEvent *) [[maybe_unused]] _event
{
    return false;
}

- (void)mouseDown:(NSEvent *)event
{
    [self.panelView panelItem:-1 mouseDown:event];
}

- (void)mouseUp:(NSEvent *) [[maybe_unused]] _event
{
}

static NSEvent *SwapScrollAxis(NSEvent *_event)
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
    if( event.phase == NSEventPhaseNone && event.momentumPhase == NSEventPhaseNone &&
        !event.hasPreciseScrollingDeltas && event.deltaX == 0.0 && event.deltaY != 0.0 ) {
        // for vertical scroll coming from USB PC mice we swap the scroll asix, so user
        // can use mouse wheel without holding a Shift button
        if( auto new_event = SwapScrollAxis(event) )
            [super scrollWheel:new_event];
        return;
    }

    [super scrollWheel:event];
}

@end
