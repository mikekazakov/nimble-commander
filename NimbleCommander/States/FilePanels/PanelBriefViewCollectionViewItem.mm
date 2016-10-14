#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefView.h"

@interface PanelBriefViewItemCarrier : NSView

@property (nonatomic) NSColor       *background;
@property (nonatomic) NSColor *regularBackgroundColor;
@property (nonatomic) NSColor *alternateBackgroundColor;
@property (nonatomic) NSString      *filename;
@property (nonatomic) NSColor       *filenameColor;
@property (nonatomic) NSImageRep    *icon;
@property (nonatomic) PanelBriefViewItemLayoutConstants layoutConstants;
@end

@implementation PanelBriefViewItemCarrier
{
    NSColor     *m_Background;
    NSColor     *m_TextColor;
    NSString    *m_Filename;
    NSImageRep  *m_Icon;
    PanelBriefViewItemLayoutConstants m_LayoutConstants;
}

@synthesize background = m_Background;
@synthesize regularBackgroundColor;
@synthesize alternateBackgroundColor;
@synthesize filename = m_Filename;
@synthesize layoutConstants = m_LayoutConstants;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_TextColor = NSColor.blackColor;
//        m_Background = NSColor.yellowColor;
        m_Filename = @"";
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
    auto aa = [self layer];
    const auto bounds = self.bounds;

    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    if( m_Background  ) {
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(bounds));
    }
    else {
        bool is_odd = int(self.frame.origin.y / bounds.size.height) % 2;
        CGContextSetFillColorWithColor(context, is_odd ? self.alternateBackgroundColor.CGColor : self.regularBackgroundColor.CGColor);
        CGContextFillRect(context, NSRectToCGRect(bounds));
    }
    
    CGContextSetShouldSmoothFonts(context, true);
    CGContextSetShouldAntialias(context, true);
    
    const auto text_rect = NSMakeRect(2 * m_LayoutConstants.inset_left + m_LayoutConstants.icon_size,
                                      m_LayoutConstants.font_baseline,
                                      bounds.size.width - 2 * m_LayoutConstants.inset_left - m_LayoutConstants.icon_size - m_LayoutConstants.inset_right,
                                      0);

    NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new];
    item_text_pstyle.alignment = NSLeftTextAlignment;
    item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;

    auto attrs = @{NSFontAttributeName: [NSFont labelFontOfSize:13],
                   NSForegroundColorAttributeName: m_TextColor,
                   NSParagraphStyleAttributeName: item_text_pstyle};
    
    [m_Filename drawWithRect:text_rect options:0 attributes:attrs];
    
    
    const auto icon_rect = NSMakeRect(m_LayoutConstants.inset_left,
                                      (bounds.size.height - m_LayoutConstants.icon_size) / 2. - 0.5,
                                      m_LayoutConstants.icon_size,
                                      m_LayoutConstants.icon_size);
    [m_Icon drawInRect:icon_rect
              fromRect:NSZeroRect
             operation:NSCompositeSourceOver
              fraction:1.0
        respectFlipped:false
                 hints:nil];
    
    
//    NSImageRep *image_rep = m_IconCache.ImageFor(item, item_vd);
//    NSRect icon_rect = NSMakeRect(start_x + g_TextInsetsInLine[0],
//                                  item_start_y + floor((m_LineHeight - icon_size) / 2. - 0.5),
//                                  icon_size,
//                                  icon_size);
//    [image_rep drawInRect:icon_rect
//                 fromRect:NSZeroRect
//                operation:NSCompositeSourceOver
//                 fraction:1.0
//           respectFlipped:YES
//                    hints:nil];
//    
//    // Draw symlink arrow over an icon
//    if(item.IsSymlink())
//        [m_SymlinkArrowImage drawInRect:NSMakeRect(start_x + g_TextInsetsInLine[0],
//                                                   item_start_y + m_LineHeight - m_SymlinkArrowImage.size.height - 1,
//                                                   m_SymlinkArrowImage.size.width,
//                                                   m_SymlinkArrowImage.size.height)
//                               fromRect:NSZeroRect
//                              operation:NSCompositeSourceOver
//                               fraction:1.0
//                         respectFlipped:YES
//                                  hints:nil];
}

- (void) mouseDown:(NSEvent *)event
{
    
    
}

- (void) setIcon:(NSImageRep *)icon
{
    if( m_Icon != icon ) {
        m_Icon = icon;
        [self setNeedsDisplay:true];
    }
}

- (void) setFilenameColor:(NSColor *)filenameColor
{
    if( m_TextColor != filenameColor ) {
        m_TextColor = filenameColor;
        [self setNeedsDisplay:true];
    }
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
    self.carrier.layoutConstants = self.mainView.layoutConstants;
    self.carrier.regularBackgroundColor  = self.mainView.regularBackgroundColor;
    self.carrier.alternateBackgroundColor  = self.mainView.alternateBackgroundColor;
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

- (PanelBriefView*)mainView
{
    return (PanelBriefView*)self.collectionView.delegate;
}

- (void) updateColoring
{
    assert( m_Item );
    const auto &rules = [self.mainView coloringRules];
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
}

- (void) setIcon:(NSImageRep*)_icon
{
    self.carrier.icon = _icon;
}

@end
