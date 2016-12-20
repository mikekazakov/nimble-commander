#include "../PanelViewPresentationItemsColoringFilter.h"
#include "../PanelView.h"
#include "PanelListView.h"
#include "PanelListViewNameView.h"
#include "PanelListViewRowView.h"

@interface PanelListViewRowView()

@property (nonatomic) bool isDropTarget;

@end

@implementation PanelListViewRowView
{
    VFSListingItem                  m_Item;
    PanelDataItemVolatileData         m_VD;
    NSColor*                        m_RowColor;
    DoubleColor                     m_RowDoubleColor;
    NSColor*                        m_TextColor;
    DoubleColor                     m_TextDoubleColor;
    int                             m_ItemIndex;
    bool                            m_PanelActive;
    bool                            m_IsDropTarget;
}
@synthesize rowBackgroundColor = m_RowColor;
@synthesize rowBackgroundDoubleColor = m_RowDoubleColor;
@synthesize rowTextColor = m_TextColor;
@synthesize rowTextDoubleColor = m_TextDoubleColor;
@synthesize itemIndex = m_ItemIndex;
@synthesize item = m_Item;

- (id) initWithItem:(VFSListingItem)_item
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
        m_Item = _item;
        m_ItemIndex = 0;
        m_RowColor = NSColor.whiteColor;
        m_TextColor = NSColor.blackColor;
        self.selected = false;
        [self updateColors];
        m_PanelActive = false;
        m_IsDropTarget = false;
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
        
        if( self.selected ) {
            [self updateColors];
            [self notifySubviewsToRebuildPresentation];
        }
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
        // ....
        [self updateColors];
        [self notifySubviewsToRebuildPresentation];
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
        [self notifySubviewsToRebuildPresentation];
    }
}

/*static const auto g_DateTimeParagraphStyle = []{
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.alignment = NSLeftTextAlignment;
    p.lineBreakMode = NSLineBreakByTruncatingMiddle;
    return p;
}();*/

- (void) updateColors
{
    if( self.selected )
        m_RowColor = m_PanelActive ? NSColor.blueColor : NSColor.lightGrayColor;
    else
        m_RowColor = m_ItemIndex % 2 ? NSColor.controlAlternatingRowBackgroundColors[1] : NSColor.controlAlternatingRowBackgroundColors[0];
    m_RowDoubleColor = DoubleColor(m_RowColor);
    
//    NSColor *backgroundColor;
//    self.backgroundColor = m_RowColor;
//   self.layer.backgroundColor = m_RowColor.CGColor;
    
    if(const auto list_view = self.listView) {
        const vector<PanelViewPresentationItemsColoringRule> &rules = list_view.coloringRules;
        const auto focus = self.selected && m_PanelActive;
        for( const auto &i: rules )
            if( i.filter.Filter(m_Item, m_VD) ) {
                m_TextColor = focus ? i.focused : i.regular;
                break;
            }
        m_TextDoubleColor = DoubleColor(m_TextColor);

        // build date-time view text attributes here
/*        m_DateTimeViewTextAttributes = @{NSFontAttributeName: list_view.font,
                                         NSForegroundColorAttributeName: m_TextColor,
                                         NSParagraphStyleAttributeName: g_DateTimeParagraphStyle};*/
    }
    
    [self setNeedsDisplay:true];
}

- (void)updateLayer
{
    self.layer.backgroundColor = m_RowColor.CGColor;
//    self.layer.backgroundColor = NSColor.yellowColor.CGColor;
    
}

- (BOOL)wantsUpdateLayer {
    return true;  // Tells NSView to call `updateLayer` instead of `drawRect:`
}

- (void) addSubview:(NSView *)view
{
    if( [view respondsToSelector:@selector(buildPresentation)] ) {
        [super addSubview: view];
    }
    else {
        int a = 10;
        
        
    }
    
}

- (void)addSubview:(NSView *)view positioned:(NSWindowOrderingMode)place relativeTo:(nullable NSView *)otherView
{
    /* Fuck off you NSTableView, I'll not accept your fake selection view as my child! */
}

- (void) drawRect:(NSRect)dirtyRect
{
//    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
//    CGContextSetFillColorWithColor(context, m_RowColor.CGColor);
//    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
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


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    const auto my_index = m_ItemIndex;
    if( my_index < 0 )
        return NSDragOperationNone;
    
    auto op = [self.listView.panelView panelItem:my_index operationForDragging:sender];
    if( op != NSDragOperationNone ) {
        self.isDropTarget = true;
    }
    else {
        return [self.superview draggingEntered:sender];
    }
    
    return op;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    if( self.isDropTarget ) {
        self.isDropTarget = false;
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
    
    if( self.isDropTarget ) {
        self.isDropTarget = false;        
        return [self.listView.panelView panelItem:my_index performDragOperation:sender];
    }
    else
        return [self.superview performDragOperation:sender];
}

- (bool) isDropTarget
{
    return m_IsDropTarget;
}

- (void) setIsDropTarget:(bool)isDropTarget
{
    if( m_IsDropTarget != isDropTarget ) {
        m_IsDropTarget = isDropTarget;
        if( m_IsDropTarget )
            self.layer.borderWidth = 5;
        else
            self.layer.borderWidth = 0;
    }
}

@end
