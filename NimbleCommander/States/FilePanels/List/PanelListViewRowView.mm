#include "../../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../PanelListView.h"
#include "PanelListViewNameView.h"
#include "PanelListViewRowView.h"

@implementation PanelListViewRowView
{
    VFSListingItem                  m_Item;
    PanelData::PanelVolatileData    m_VD;
    NSColor*                        m_RowColor;
    NSColor*                        m_TextColor;
    bool                            m_PanelActive;
    int                             m_ItemIndex;
}
@synthesize rowBackgroundColor = m_RowColor;
@synthesize rowTextColor = m_TextColor;
@synthesize itemIndex = m_ItemIndex;
@synthesize item = m_Item;

- (id) initWithItem:(VFSListingItem)_item atIndex:(int)index
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
        m_Item = _item;
        m_ItemIndex = index;
        m_RowColor = NSColor.whiteColor;
        m_TextColor = NSColor.blackColor;
        self.selected = false;
        [self updateColors];
        m_PanelActive = false;
    }
    return self;
}

- (void) setPanelActive:(bool)panelActive
{
    if( m_PanelActive != panelActive ) {
        m_PanelActive = panelActive;
        
        [self updateColors];
        [self notifySubviewsToRebuildPresentation];        
    }
}

- (bool) panelActive
{
    return m_PanelActive;
}

- (void) setVd:(PanelData::PanelVolatileData)vd
{
    if( m_VD != vd ) {
        m_VD = vd;
        // ....
        [self updateColors];
        [self notifySubviewsToRebuildPresentation];
    }
}

- (PanelData::PanelVolatileData) vd
{
    return m_VD;
}

- (void) setSelected:(BOOL)selected
{
    if( selected != self.selected ) {
        [super setSelected:selected];
        [self updateColors];
        [self notifySubviewsToRebuildPresentation];
    }
}

- (void) updateColors
{
    if( self.selected )
        m_RowColor = m_PanelActive ? NSColor.blueColor : NSColor.lightGrayColor;
    else
        m_RowColor = m_ItemIndex % 2 ? NSColor.controlAlternatingRowBackgroundColors[1] : NSColor.controlAlternatingRowBackgroundColors[0];
    
    if(const auto list_view = self.listView) {
        const auto &rules = list_view.coloringRules;
        const auto focus = self.selected && m_PanelActive;
        for( const auto &i: rules )
            if( i.filter.Filter(m_Item, m_VD) ) {
                m_TextColor = focus ? i.focused : i.regular;
                break;
            }
    }
    
    [self setNeedsDisplay:true];
}

- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSetFillColorWithColor(context, m_RowColor.CGColor);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
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
    }
}

- (void)didAddSubview:(NSView *)subview
{
    if( [subview respondsToSelector:@selector(buildPresentation)] )
        [(id)subview buildPresentation];
}

@end
