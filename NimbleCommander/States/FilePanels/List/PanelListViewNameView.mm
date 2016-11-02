#include "../PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewNameView.h"

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

@implementation PanelListViewNameView
{
    NSString        *m_Filename;
    NSDictionary    *m_TextAttributes;
    NSImageRep      *m_Icon;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
        //        m_Filename = _filename;
        //        self.wantsLayer = true;
//        self.wantsLayer = YES;
    }
    return self;
}

- (void) setFilename:(NSString*)_filename
{
    m_Filename = _filename;
    [self setNeedsDisplay:true];    
}

//- (void)updateLayer
//{
//    if( auto v = objc_cast<PanelListViewRowView>(self.superview) ) {
//        auto layer = self.layer;
//        self.layer.backgroundColor = v.rowBackgroundColor.CGColor;
//    }
//    
//}

//- (BOOL)wantsUpdateLayer {
//    return YES;  // Tells NSView to call `updateLayer` instead of `drawRect:`
//}

- (void) drawRect:(NSRect)dirtyRect
{
//    auto layer = self.layer;
//    auto bg = layer.backgroundColor;
    if( !((PanelListViewRowView*)self.superview).listView )
        return;
    
    const auto bounds = self.bounds;
    const auto geometry = ((PanelListViewRowView*)self.superview).listView.geometry;
    
    if( auto v = objc_cast<PanelListViewRowView>(self.superview) ) {
        const auto context = NSGraphicsContext.currentContext.CGContext;
        v.rowBackgroundDoubleColor.Set( context );
//        if( auto c = v.rowBackgroundColor  ) {
//            CGContextSetFillColorWithColor(context, c.CGColor);
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
//        }
    }
    
    const auto text_rect = NSMakeRect(2 * geometry.LeftInset() + geometry.IconSize(),
                                      geometry.TextBaseLine(),
                                      bounds.size.width - 2 * geometry.LeftInset() - geometry.IconSize() - geometry.RightInset(),
                                      0);
    
    [m_Filename drawWithRect:text_rect
                     options:0
                  attributes:m_TextAttributes];
    
    
    const auto icon_rect = NSMakeRect(geometry.LeftInset(),
                                      (bounds.size.height - geometry.IconSize()) / 2. + 0.5,
                                      geometry.IconSize(),
                                      geometry.IconSize());
    [m_Icon drawInRect:icon_rect
              fromRect:NSZeroRect
             operation:NSCompositeSourceOver
              fraction:1.0
        respectFlipped:false
                 hints:nil];
    
//    [m_Filename drawWithRect:self.bounds
//                     options:0
//                  attributes:m_TextAttributes];
}

- (void) buildPresentation
{
    PanelListViewRowView *row_view = (PanelListViewRowView*)self.superview;
//    self.layer.backgroundColor = row_view.rowBackgroundColor.CGColor;
//    self.layer.backgroundColor = NSColor.redColor.CGColor;
// self.layer.backgroundColor = m_RowColor.CGColor;
    m_TextAttributes = @{NSFontAttributeName:row_view.listView.font,
                         NSForegroundColorAttributeName: row_view.rowTextColor,
                         NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};
    
    [self setNeedsDisplay:true];
//    [self updateLayer];
//    self.wantsUpdateLayer = true;
}

//@property (nonatomic) NSImageRep *icon;
- (void) setIcon:(NSImageRep *)icon
{
    if( m_Icon != icon ) {
        m_Icon = icon;
        
        [self setNeedsDisplay:true];
    }
}

- (NSImageRep*)icon
{
    return m_Icon;
}

@end

