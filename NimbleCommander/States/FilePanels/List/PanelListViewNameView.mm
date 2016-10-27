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
        
    }
    return self;
}

- (void) setFilename:(NSString*)_filename
{
    m_Filename = _filename;
}

- (void) drawRect:(NSRect)dirtyRect
{
    if( auto v = objc_cast<PanelListViewRowView>(self.superview) ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        
        if( auto c = v.rowBackgroundColor  ) {
            CGContextSetFillColorWithColor(context, c.CGColor);
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
        }
    }
    
    [m_Filename drawWithRect:self.bounds
                     options:0
                  attributes:m_TextAttributes];
}

- (void) buildPresentation
{
    m_TextAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:13],
                         NSForegroundColorAttributeName: ((PanelListViewRowView*)self.superview).rowTextColor,
                         NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};
    
    [self setNeedsDisplay:true];
}

@end

