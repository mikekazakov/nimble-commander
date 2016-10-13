#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefView.h"

@interface PanelBriefViewItemCarrier : NSView

@property NSTextField *label;
@property NSColor *background;

@property NSString *filename;
@property NSColor *filenameColor;

@end

@implementation PanelBriefViewItemCarrier
{
    NSColor *m_Background;
    NSColor *m_TextColor;
    NSString *m_Filename;
}

@synthesize label = m_Label;
@synthesize background = m_Background;
@synthesize filename = m_Filename;
@synthesize filenameColor = m_TextColor;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        
        m_TextColor = NSColor.blackColor;
        m_Background = NSColor.yellowColor;
//        cout << "spawn" << endl;
    }
    return self;
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self setNeedsDisplay:true];
}

- (void) setFrame:(NSRect)frame
{
    [super setFrame:frame];
    [self setNeedsDisplay:true];
}

- (void)drawRect:(NSRect)dirtyRect
{
    static const double m_LineHeight = 20;
    static const double m_LineTextBaseline = m_LineHeight - 4;
    
    static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};
    
    
    
    
    if( m_Background  ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    }

    NSRect rect = NSMakeRect(0,
                             /*item_start_y + m_LineTextBaseline*/4,
                             /*column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2]*/self.bounds.size.width,
                             /*m_FontHeight*/0);
    
    
    
    NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new];
    item_text_pstyle.alignment = NSLeftTextAlignment;
    item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
    

    auto attrs = @{NSFontAttributeName: [NSFont labelFontOfSize:13],
                   NSForegroundColorAttributeName: m_TextColor,
                   NSParagraphStyleAttributeName: item_text_pstyle};
    
    
    
    
    [m_Filename drawWithRect:/*self.bounds*/rect
                     options:0
                  attributes:attrs];
}

@end

//<NSCollectionViewElement>

@implementation PanelBriefViewItem
{
    VFSListingItem                  m_Item;
    PanelData::PanelVolatileData    m_VD;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
}

- (nullable instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        self.view = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
    }
    return self;
}

- (PanelBriefViewItemCarrier*) carrier
{
    return (PanelBriefViewItemCarrier*)self.view;
}

- (void) setItem:(VFSListingItem)_item
{
    m_Item = _item;
    
    self.carrier.filename = m_Item.NSDisplayName();
    [self.carrier setNeedsDisplay:true];
}

- (void)setSelected:(BOOL)selected
{
    if( self.selected == selected )
        return;
    [super setSelected:selected];
    
    if( selected )
        self.carrier.background = NSColor.blueColor;
    else
        self.carrier.background = nil/*NSColor.yellowColor*/;
    
    if( m_Item)
        [self updateColoring];
    [self.carrier setNeedsDisplay:true];
}

- (void) updateColoring
{
    assert( m_Item );
    const auto &rules = [((PanelBriefView*)self.collectionView.delegate) coloringRules];
    for( const auto &i: rules )
        if( i.filter.Filter(m_Item, m_VD) ) {
            self.carrier.filenameColor = self.selected ? i.focused : i.regular;
            break;
        }
}

- (void) setVD:(PanelData::PanelVolatileData)_vd
{
    if( m_VD == _vd )
        return;
    m_VD = _vd;
    [self updateColoring];
    [self.carrier setNeedsDisplay:true];    
}

@end
