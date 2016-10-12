#include "../../../Files/PanelViewPresentationItemsColoringFilter.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefView.h"

@interface PanelBriefViewItemCarrier : NSView

@property NSTextField *label;
@property NSColor *background;

@end

@implementation PanelBriefViewItemCarrier
{
    NSTextField *m_Label;
    NSColor *m_Background;
}

@synthesize label = m_Label;
@synthesize background = m_Background;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 50, 20)];
        m_Label.bordered = false;
        m_Label.editable = false;
        m_Label.drawsBackground = false;
        m_Label.font = [NSFont labelFontOfSize:13];
        m_Label.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:m_Label];
        
//        m_Background = NSColor.yellowColor;
    }
    return self;
}

- (void) doLayout
{
    [m_Label setFrame:NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height)];
}

- (void)setFrameOrigin:(NSPoint)newOrigin
{
    [super setFrameOrigin:newOrigin];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self doLayout];
}

- (void) setFrame:(NSRect)frame
{
    [super setFrame:frame];
    [self doLayout];
}

//@property NSRect frame;

//-(id)initWithCoder:(NSCoder *)coder
//{
//    self = [super initWithCoder:coder];
//    if( self ) {
//        m_Label = [coder decodeObjectForKey:@"label"];
//        m_Background = [coder decodeObjectForKey:@"background"];
//    }
//    return self;
//}

//- (void)encodeWithCoder: (NSCoder *)coder
//{
//    [super encodeWithCoder:coder];
//    [coder encodeObject:m_Label forKey:@"label"];
//    [coder encodeObject:m_Background forKey: @"background"];
//}

- (void)drawRect:(NSRect)dirtyRect
{
    if( m_Background  ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    }
}

@end


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
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if( self ) {
        //        static PanelBriefViewItemCarrier* proto = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        //        static
        //        NSKeyedArchiver
        //        static NSData *archived_proto = [NSKeyedArchiver archivedDataWithRootObject:proto];
        //        NSView * myViewCopy = [NSKeyedUnarchiver unarchiveObjectWithData:archivedView];
        
        //self.view = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        
        //        MachTimeBenchmark mtb;
        self.view = [[PanelBriefViewItemCarrier alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        //        self.view = [NSKeyedUnarchiver unarchiveObjectWithData:archived_proto];
        //        mtb.ResetMicro("PanelBriefViewItemCarrier ");
        
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
    
    self.carrier.label.stringValue = m_Item.NSDisplayName();
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
//    PanelBriefView.h
    for( const auto &i: rules ) {
        if( i.filter.Filter(m_Item, m_VD) ) {
            self.carrier.label.textColor = self.selected ? i.focused : i.regular;
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

@end
