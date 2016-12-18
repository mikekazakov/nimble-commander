#include "../PanelViewPresentationItemsColoringFilter.h"
#include "../PanelView.h"
#include "../PanelController+DragAndDrop.h"
#include "PanelListView.h"
#include "PanelListViewNameView.h"
#include "PanelListViewRowView.h"

@implementation PanelListViewRowView
{
    VFSListingItem                  m_Item;
    PanelDataItemVolatileData         m_VD;
    NSColor*                        m_RowColor;
    DoubleColor                     m_RowDoubleColor;
    NSColor*                        m_TextColor;
    DoubleColor                     m_TextDoubleColor;
    bool                            m_PanelActive;
    int                             m_ItemIndex;
//    NSDictionary                   *m_DateTimeViewTextAttributes;
}
@synthesize rowBackgroundColor = m_RowColor;
@synthesize rowBackgroundDoubleColor = m_RowDoubleColor;
@synthesize rowTextColor = m_TextColor;
@synthesize rowTextDoubleColor = m_TextDoubleColor;
@synthesize itemIndex = m_ItemIndex;
@synthesize item = m_Item;
//@synthesize dateTimeViewTextAttributes = m_DateTimeViewTextAttributes;

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
//        self.wantsLayer = true;
//        self.canDrawSubviewsIntoLayer = true;
//        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
        [self registerForDraggedTypes:PanelController.acceptedDragAndDropTypes];
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
        const auto &rules = list_view.coloringRules;
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
        if( hypot(lp.x - g_LastMouseDownPos.x, lp.y - g_LastMouseDownPos.y) > max_drag_dist ) {
//            const int clicked_pos = m_Presentation->GetItemIndexByPointInView(m_LButtonDownPos, PanelViewHitTest::FullArea);
//            if( clicked_pos == -1 )
//                return;
            const auto my_index = m_ItemIndex;
            if( my_index < 0 )
                return;
            
//            NSLog(@"Drag");
            
//            [self.delegate panelView:self wantsToDragItemNo:clicked_pos byEvent:_event];
            
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
    cout << "draggingEntered" << endl;
    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    cout << "draggingUpdated" << endl;
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    cout << "draggingExited" << endl;
}

@end
