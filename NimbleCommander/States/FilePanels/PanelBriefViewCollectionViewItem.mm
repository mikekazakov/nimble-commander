#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "../../../Files/PanelView.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefView.h"

static NSParagraphStyle *ParagraphStyle( NSLineBreakMode _mode )
{
    static NSParagraphStyle *styles[3];
    static once_flag once;
    call_once(once, []{
        NSMutableParagraphStyle *p0 = [NSMutableParagraphStyle new];
        p0.alignment = NSLeftTextAlignment;
        p0.lineBreakMode = NSLineBreakByTruncatingHead;
        styles[0] = p0;
        
        NSMutableParagraphStyle *p1 = [NSMutableParagraphStyle new];
        p1.alignment = NSLeftTextAlignment;
        p1.lineBreakMode = NSLineBreakByTruncatingTail;
        styles[1] = p1;

        NSMutableParagraphStyle *p2 = [NSMutableParagraphStyle new];
        p2.alignment = NSLeftTextAlignment;
        p2.lineBreakMode = NSLineBreakByTruncatingMiddle;
        styles[2] = p2;
    });
    
    switch( _mode ) {
        case NSLineBreakByTruncatingHead:   return styles[0];
        case NSLineBreakByTruncatingTail:   return styles[1];
        case NSLineBreakByTruncatingMiddle: return styles[2];
        default:                            return nil;
    }
}

@interface PanelBriefViewItemCarrier : NSView

@property (nonatomic, weak) PanelBriefViewItem                 *controller;
@property (nonatomic)       NSColor                            *background;
@property (nonatomic)       NSColor                            *regularBackgroundColor;
@property (nonatomic)       NSColor                            *alternateBackgroundColor;
@property (nonatomic)       NSString                           *filename;
@property (nonatomic)       NSColor                            *filenameColor;
@property (nonatomic)       NSImageRep                         *icon;
@property (nonatomic)       PanelBriefViewItemLayoutConstants   layoutConstants;
@end

@implementation PanelBriefViewItemCarrier
{
    NSColor                            *m_Background;
    NSColor                            *m_TextColor;
    NSString                           *m_Filename;
    NSImageRep                         *m_Icon;
    NSFont                             *m_Font;
    NSDictionary                       *m_TextAttributes;
    PanelBriefViewItemLayoutConstants   m_LayoutConstants;
    __weak PanelBriefViewItem          *m_Controller;
}

@synthesize background = m_Background;
@synthesize regularBackgroundColor;
@synthesize alternateBackgroundColor;
@synthesize filename = m_Filename;
@synthesize layoutConstants = m_LayoutConstants;
@synthesize controller = m_Controller;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_TextColor = NSColor.blackColor;
        m_Font = [NSFont systemFontOfSize:13];
        m_Filename = @"";
        [self buildTextAttributes];
    }
    return self;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
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
    const auto bounds = self.bounds;

    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    
    if( m_Background  ) {
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(bounds));
    }
    else {
        bool is_odd = int(self.frame.origin.y / bounds.size.height) % 2;
        CGContextSetFillColorWithColor(context, is_odd ? self.alternateBackgroundColor.CGColor : self.regularBackgroundColor.CGColor);
        CGContextFillRect(context, NSRectToCGRect(bounds));
    }
    
    const auto text_rect = NSMakeRect(2 * m_LayoutConstants.inset_left + m_LayoutConstants.icon_size,
                                      m_LayoutConstants.font_baseline,
                                      bounds.size.width - 2 * m_LayoutConstants.inset_left - m_LayoutConstants.icon_size - m_LayoutConstants.inset_right,
                                      0);
    
    [m_Filename drawWithRect:text_rect
                     options:0
                  attributes:m_TextAttributes];
    
    
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

}

- (void) mouseDown:(NSEvent *)event
{
    /// ...
    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return;
    
    [m_Controller.briefView.panelView panelItem:my_index mouseDown:event];
    
    // check if focus and selection didn't change - in that case allow renaming 
}

- (void)mouseUp:(NSEvent *)event
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
        [self buildTextAttributes];
        [self setNeedsDisplay:true];
    }
}

- (void) setBackground:(NSColor *)background
{
    if( m_Background != background ) {
        m_Background = background;
        [self setNeedsDisplay:true];
    }
}

- (void) buildTextAttributes
{
    m_TextAttributes = @{NSFontAttributeName: m_Font,
                         NSForegroundColorAttributeName: m_TextColor,
                         NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};
}

@end

@implementation PanelBriefViewItem
{
    VFSListingItem                  m_Item;
    PanelData::PanelVolatileData    m_VD;
    bool                            m_PanelActive;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Item = VFSListingItem{};
    m_VD = PanelData::PanelVolatileData{};
    m_PanelActive = false;
}

- (nullable instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        m_PanelActive = false;
        PanelBriefViewItemCarrier *v = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        v.controller = self;
        self.view = v;
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
    self.carrier.layoutConstants = self.briefView.layoutConstants;
    self.carrier.regularBackgroundColor  = self.briefView.regularBackgroundColor;
    self.carrier.alternateBackgroundColor  = self.briefView.alternateBackgroundColor;
    [self.carrier setNeedsDisplay:true];
}


- (void) setPanelActive:(bool)_active
{
    if( m_PanelActive != _active ) {
        m_PanelActive = _active;
        
        if( self.selected  ) {
            self.carrier.background = self.selectedBackgroundColor;
            if( m_Item )
                [self updateColoring];
        }
    }
}

- (void)setSelected:(BOOL)selected
{
    if( self.selected == selected )
        return;
    [super setSelected:selected];
    
    self.carrier.background = selected ? self.selectedBackgroundColor : nil;
    if( m_Item )
        [self updateColoring];
}

- (NSColor*) selectedBackgroundColor
{
    if( m_PanelActive )
        return NSColor.blueColor;
    else
        return NSColor.lightGrayColor;
}

- (PanelBriefView*)briefView
{
    return (PanelBriefView*)self.collectionView.delegate;
}

- (int) itemIndex
{
    if( auto c = self.collectionView )
        if( auto p = [c indexPathForItem:self] )
            return (int)p.item;
    return -1;
}

- (void) updateColoring
{
    assert( m_Item );
    if( self.briefView ) {
    const auto &rules = [self.briefView coloringRules];
    const bool focus = self.selected && m_PanelActive;
    for( const auto &i: rules )
        if( i.filter.Filter(m_Item, m_VD) ) {
            self.carrier.filenameColor = focus ? i.focused : i.regular;
            break;
        }
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
