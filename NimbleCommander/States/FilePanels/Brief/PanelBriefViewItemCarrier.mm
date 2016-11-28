#include <Utility/FontExtras.h>
#include "../../../Files/PanelView.h"
#include "../PanelBriefView.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewItemCarrier.h"

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

@implementation PanelBriefViewItemCarrier
{
    NSColor                            *m_Background;
    NSColor                            *m_TextColor;
    NSString                           *m_Filename;
    NSImageRep                         *m_Icon;
    NSFont                             *m_Font;
    NSMutableAttributedString          *m_AttrString;
    PanelBriefViewItemLayoutConstants   m_LayoutConstants;
    __weak PanelBriefViewItem          *m_Controller;
    pair<int16_t, int16_t>              m_QSHighlight;
}

@synthesize background = m_Background;
@synthesize regularBackgroundColor;
@synthesize alternateBackgroundColor;
@synthesize filename = m_Filename;
@synthesize layoutConstants = m_LayoutConstants;
@synthesize controller = m_Controller;
@synthesize qsHighlight = m_QSHighlight;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_TextColor = NSColor.blackColor;
        m_Font = [NSFont systemFontOfSize:13];
        m_Filename = @"";
        m_QSHighlight = {0, 0};
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
    
    [m_AttrString drawWithRect:text_rect
                       options:0];
    
    const auto icon_rect = NSMakeRect(m_LayoutConstants.inset_left,
                                      (bounds.size.height - m_LayoutConstants.icon_size) / 2. + 0.5,
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

- (void) setFilename:(NSString *)filename
{
    if( m_Filename != filename ) {
        m_Filename = filename;
        [self buildTextAttributes];
        [self setNeedsDisplay:true];
    }
}

- (void) buildTextAttributes
{
    NSDictionary *attrs = @{NSFontAttributeName: m_Font,
                            NSForegroundColorAttributeName: m_TextColor,
                            NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};
    
    m_AttrString = [[NSMutableAttributedString alloc] initWithString:m_Filename
                                                          attributes:attrs];
    
    if( m_QSHighlight.first != m_QSHighlight.second )
        if( m_QSHighlight.first < m_Filename.length && m_QSHighlight.second <= m_Filename.length  )
            [m_AttrString addAttribute:NSUnderlineStyleAttributeName
                                 value:@(NSUnderlineStyleSingle)
                                 range:NSMakeRange(m_QSHighlight.first, m_QSHighlight.second - m_QSHighlight.first)];
}

- (void) setQsHighlight:(pair<int16_t, int16_t>)qsHighlight
{
    if( m_QSHighlight != qsHighlight ) {
        m_QSHighlight = qsHighlight;
        [self buildTextAttributes];
        [self setNeedsDisplay:true];
    }
}

- (void) setupFieldEditor:(NSScrollView*)_editor
{
    const auto line_padding = 2.;
    
    const auto bounds = self.bounds;
    NSRect rc =  NSMakeRect(2 * m_LayoutConstants.inset_left + m_LayoutConstants.icon_size,
                            0,
                            bounds.size.width - 2 * m_LayoutConstants.inset_left - m_LayoutConstants.icon_size - m_LayoutConstants.inset_right,
                            bounds.size.height);
    
    auto fi = FontGeometryInfo(m_Font);
    
    rc.size.height = fi.LineHeight();
    rc.origin.y += 1;
    rc.origin.x -= line_padding;
    
    _editor.frame = rc;
    
    NSTextView *tv = _editor.documentView;
    tv.font = m_Font;
    tv.textContainerInset = NSMakeSize(0, 0);
    tv.textContainer.lineFragmentPadding = line_padding;
    auto aa = tv.textContainerOrigin;
    
    
    [self addSubview:_editor];
}

@end
