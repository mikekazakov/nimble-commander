#include <NimbleCommander/Core/Theming/Theme.h>
#include "../PanelViewPresentationItemsColoringFilter.h"
#include "../PanelView.h"
#include "PanelListView.h"
#include "PanelListViewNameView.h"
#include "PanelListViewSizeView.h"
#include "PanelListViewRowView.h"

@interface PanelListViewRowView()

@property (nonatomic) bool dropTarget;
@property (nonatomic) bool highlighted;

@end

@implementation PanelListViewRowView
{
    VFSListingItem                  m_Item;
    PanelDataItemVolatileData         m_VD;
    NSColor*                        m_RowColor;
    NSColor*                        m_TextColor;
    int                             m_ItemIndex;
    bool                            m_PanelActive;
    bool                            m_DropTarget;
    bool                            m_Highlighted;
}
@synthesize rowBackgroundColor = m_RowColor;
@synthesize rowTextColor = m_TextColor;
@synthesize itemIndex = m_ItemIndex;
@synthesize item = m_Item;

- (id) initWithItem:(VFSListingItem)_item
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
        m_PanelActive = false;
        m_DropTarget = false;
        m_Highlighted = false;
        m_Item = _item;
        m_ItemIndex = 0;
        m_RowColor = NSColor.whiteColor;
        m_TextColor = NSColor.blackColor;
        self.selected = false;
        [self updateColors];
//        self.wantsLayer = true;
//        self.canDrawSubviewsIntoLayer = true;
//        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
        [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];
    }
    return self;
}

- (void) setItemIndex:(int)itemIndex
{
    m_ItemIndex = itemIndex;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (void) setPanelActive:(bool)panelActive
{
    if( m_PanelActive != panelActive ) {
        m_PanelActive = panelActive;
        if( self.selected )
            [self updateColors];
    }
}

- (void)setItem:(VFSListingItem)item
{
    if( m_Item != item ) {
        m_Item = item; /// ....
    }
}

- (bool) panelActive
{
    return m_PanelActive;
}

- (void) setVd:(PanelDataItemVolatileData)vd
{
    if( m_VD != vd ) {
        m_VD = vd;
        [self updateColors];
        [self.sizeView setSizeWithItem:m_Item andVD:m_VD];
        self.highlighted = vd.is_highlighted();
    }
}

- (PanelData::VolatileData) vd
{
    return m_VD;
}

- (void) setSelected:(BOOL)selected
{
    if( selected != self.selected ) {
        [super setSelected:selected];
        [self updateLayer];
        [self updateColors];
    }
}

- (NSColor*) findCurrentBackgroundColor
{
    if( self.selected )
        return m_PanelActive ?
            CurrentTheme().FilePanelsListSelectedActiveRowBackgroundColor() :
            CurrentTheme().FilePanelsListSelectedInactiveRowBackgroundColor();
    else
        return m_ItemIndex % 2 ?
            CurrentTheme().FilePanelsListRegularOddRowBackgroundColor() :
            CurrentTheme().FilePanelsListRegularEvenRowBackgroundColor();
}

- (NSColor*) findCurrentTextColor
{
    if( !m_Item )
        return NSColor.blackColor;

    const auto &rules = CurrentTheme().FilePanelsItemsColoringRules();;
    const auto focus = self.selected && m_PanelActive;
    for( const auto &i: rules )
        if( i.filter.Filter(m_Item, m_VD) )
            return focus ? i.focused : i.regular;

    return NSColor.blackColor;
}

- (void) updateColors
{
    auto colors_has_changed = false;
    
    auto new_row_bg_color = [self findCurrentBackgroundColor];
    if( m_RowColor != new_row_bg_color ) {
        m_RowColor = new_row_bg_color;
        colors_has_changed = true;
    }
    
    auto new_row_fg_color = [self findCurrentTextColor];
    if( new_row_fg_color != m_TextColor ) {
        m_TextColor = new_row_fg_color;
        colors_has_changed = true;
    }
    
    if( colors_has_changed ) {
        [self setNeedsDisplay:true];
        [self notifySubviewsToRebuildPresentation];
    }
}

- (BOOL)wantsUpdateLayer
{
    return true; // just use background color
}

- (void)updateLayer
{
    self.layer.backgroundColor = m_RowColor.CGColor;
}

- (void) drawRect:(NSRect)dirtyRect
{
}

- (void) addSubview:(NSView *)view
{
    if( [view respondsToSelector:@selector(buildPresentation)] ) {
        [super addSubview: view];
    }
    else {
    }    
}

- (void)addSubview:(NSView *)view positioned:(NSWindowOrderingMode)place relativeTo:(nullable NSView *)otherView
{
    /* Fuck off you NSTableView, I'll not accept your fake selection view as my child! */
}

//- (void)display {}
//- (void)displayIfNeeded{}
//- (void)displayIfNeededIgnoringOpacity{}
//- (void)displayRect:(NSRect)rect{}
//- (void)displayRectIgnoringOpacity:(NSRect)rect inContext:(NSGraphicsContext *)context{}
//
//- (void)displayIfNeededInRect:(NSRect)rect{}
//- (void)displayIfNeededInRectIgnoringOpacity:(NSRect)rect{}


- (void)display{}
- (void)displayIfNeeded{}
- (void)displayIfNeededIgnoringOpacity{}
- (void)displayRect:(NSRect)rect{}
- (void)displayIfNeededInRect:(NSRect)rect{}
- (void)displayRectIgnoringOpacity:(NSRect)rect{}
- (void)displayIfNeededInRectIgnoringOpacity:(NSRect)rect{}
//- (void)drawRect:(NSRect)dirtyRect{}
- (void)displayRectIgnoringOpacity:(NSRect)rect inContext:(NSGraphicsContext *)context{}

- (void)drawBackgroundInRect:(NSRect)dirtyRect
{
}

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
}

- (void)drawSeparatorInRect:(NSRect)dirtyRect
{
}

- (void)drawDraggingDestinationFeedbackInRect:(NSRect)dirtyRect
{
}

- (void)viewDidMoveToSuperview
{
    if( self.superview )
        [self notifySubviewsToRebuildPresentation];
    
}

- (void) notifySubviewsToRebuildPresentation
{
    for( NSView *w in self.subviews ) {
        if( [w respondsToSelector:@selector(buildPresentation)] )
            [(id)w buildPresentation];
        
//        w.layer.backgroundColor = m_RowColor.CGColor;
    }
}

- (void)didAddSubview:(NSView *)subview
{
    if( [subview respondsToSelector:@selector(buildPresentation)] )
        [(id)subview buildPresentation];
}

- (PanelListViewNameView*) nameView
{
    return objc_cast<PanelListViewNameView>([self viewAtColumn:0]); // need to force index #0 somehow
}

- (PanelListViewSizeView *) sizeView
{
    for( NSView *child in self.subviews )
        if( auto v = objc_cast<PanelListViewSizeView>(child) )
            return v;
    return nil;
}

- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

static bool     g_RowReadyToDrag = false;
static void*    g_MouseDownRow = nullptr;
static NSPoint  g_LastMouseDownPos = {};
//m_LButtonDownPos

- (void) mouseDown:(NSEvent *)event
{
    const auto my_index = m_ItemIndex;
    if( my_index < 0 )
        return;

    [self.listView.panelView panelItem:my_index mouseDown:event];
    
    const auto lb_pressed = (NSEvent.pressedMouseButtons & 1) == 1;
    const auto local_point = [self convertPoint:event.locationInWindow fromView:nil];
    
    if( lb_pressed ) {
        g_RowReadyToDrag = true;
        g_MouseDownRow = (__bridge void*)self;
        g_LastMouseDownPos = local_point;
    }
}

- (void)mouseUp:(NSEvent *)event
{
    const auto my_index = m_ItemIndex;
    if( my_index < 0 )
        return;
    const int click_count = (int)event.clickCount;
    // Handle double-or-four-etc clicks as double-click
    if( click_count == 2 || click_count == 4 || click_count == 6 || click_count == 8 )
        [self.listView.panelView panelItem:my_index dblClick:event];
    
    g_RowReadyToDrag = false;
    g_MouseDownRow = nullptr;
    g_LastMouseDownPos = {};
}

- (void) mouseDragged:(NSEvent *)event
{
    const auto max_drag_dist = 5.;
    if( g_RowReadyToDrag &&  g_MouseDownRow == (__bridge void*)self ) {
        const auto lp = [self convertPoint:event.locationInWindow fromView:nil];
        const auto dist = hypot(lp.x - g_LastMouseDownPos.x, lp.y - g_LastMouseDownPos.y);
        if( dist > max_drag_dist ) {
            const auto my_index = m_ItemIndex;
            if( my_index < 0 )
                return;
            
            [self.listView.panelView panelItem:my_index mouseDragged:event];
            g_RowReadyToDrag = false;
            g_MouseDownRow = nullptr;
            g_LastMouseDownPos = {};
        }
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)_event
{
    const auto my_index = m_ItemIndex;
    if( my_index < 0 )
        return nil;
    
    return [self.listView.panelView panelItem:my_index menuForForEvent:_event];
}

- (bool) validateDropHitTest:(id <NSDraggingInfo>)sender
{
    const auto sv_position = [self.superview convertPoint:sender.draggingLocation fromView:nil];
    if( id v = [self hitTest:sv_position] )
        if( [v respondsToSelector:@selector(dragAndDropHitTest:)] ) {
            const auto v_position = [v convertPoint:sender.draggingLocation fromView:nil];
            return [v dragAndDropHitTest:v_position];
        }
    return true;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    const auto my_index = m_ItemIndex;
    if( my_index < 0 )
        return NSDragOperationNone;

    if( [self validateDropHitTest:sender] ) {
        const auto op = [self.listView.panelView panelItem:my_index operationForDragging:sender];
        if( op != NSDragOperationNone ) {
            self.dropTarget = true;
            [self.superview draggingExited:sender];
            return op;
        }
    }

    self.dropTarget = false;
    return [self.superview draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    if( self.dropTarget ) {
        self.dropTarget = false;
    }
    else {
        [self.superview draggingExited:sender];
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    // possibly add some checking stage here later
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    const auto my_index = m_ItemIndex;
    if( my_index < 0 )
        return false;
    
    if( self.dropTarget ) {
        self.dropTarget = false;
        return [self.listView.panelView panelItem:my_index performDragOperation:sender];
    }
    else
        return [self.superview performDragOperation:sender];
}

- (bool) dropTarget
{
    return m_DropTarget;
}

- (void) setDropTarget:(bool)isDropTarget
{
    if( m_DropTarget != isDropTarget ) {
        m_DropTarget = isDropTarget;
        [self updateBorder];
    }
}

- (bool) isHighlighted
{
    return m_Highlighted;
}

- (void) setHighlighted:(bool)highlighted
{
    if( m_Highlighted != highlighted ) {
        m_Highlighted = highlighted;
        [self updateBorder];
    }
}

- (void) updateBorder
{
    if( m_DropTarget || m_Highlighted ) {
        self.layer.borderWidth = 1;
        self.layer.borderColor = CurrentTheme().FilePanelsGeneralDropBorderColor().CGColor;
    }
    else
        self.layer.borderWidth = 0;
}

@end
