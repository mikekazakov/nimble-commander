#include <Utility/FontExtras.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include "../PanelView.h"
#include "../PanelViewPresentationSettings.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewItemCarrier.h"

static const auto g_SymlinkArrowImage = [NSImage imageNamed:@"AliasBadgeIcon"];

static NSParagraphStyle *ParagraphStyle( PanelViewFilenameTrimming _mode )
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
        case PanelViewFilenameTrimming::Heading:    return styles[0];
        case PanelViewFilenameTrimming::Trailing:   return styles[1];
        case PanelViewFilenameTrimming::Middle:     return styles[2];
        default:                                    return nil;
    }
}

@implementation PanelBriefViewItemCarrier
{
    NSColor                            *m_Background;
    NSColor                            *m_TextColor;
    NSString                           *m_Filename;
    NSImage                            *m_Icon;
    NSMutableAttributedString          *m_AttrString;
    PanelBriefViewItemLayoutConstants   m_LayoutConstants;
    __weak PanelBriefViewItem          *m_Controller;
    pair<int16_t, int16_t>              m_QSHighlight;
    bool                                m_Highlighted;
    bool                                m_PermitFieldRenaming;
    bool                                m_IsDropTarget;
}

@synthesize background = m_Background;
@synthesize filename = m_Filename;
@synthesize layoutConstants = m_LayoutConstants;
@synthesize controller = m_Controller;
@synthesize qsHighlight = m_QSHighlight;
@synthesize highlighted = m_Highlighted;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_TextColor = NSColor.blackColor;
        m_Filename = @"";
        m_QSHighlight = {0, 0};
        m_PermitFieldRenaming = false;
        [self buildTextAttributes];
        [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];        
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

- (NSRect) calculateTextSegmentFromBounds:(NSRect)bounds
{
    const int origin = m_LayoutConstants.icon_size ?
        2 * m_LayoutConstants.inset_left + m_LayoutConstants.icon_size :
        m_LayoutConstants.inset_left;
    const int width = bounds.size.width - origin - m_LayoutConstants.inset_right;

    return NSMakeRect(origin, 0, width, bounds.size.height);
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
        const bool is_odd = int(self.frame.origin.y / bounds.size.height) % 2;
        auto c = is_odd ?
            CurrentTheme().FilePanelsBriefRegularOddRowBackgroundColor() :
            CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor();
        CGContextSetFillColorWithColor(context, c.CGColor);
        CGContextFillRect(context, NSRectToCGRect(bounds));
    }
    
    const auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds];
    const auto text_rect = NSMakeRect(text_segment_rect.origin.x,
                                      m_LayoutConstants.font_baseline,
                                      text_segment_rect.size.width,
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
    
    // Draw symlink arrow over an icon
    const auto is_symlink = m_Controller && m_Controller.item.IsSymlink();
    if( is_symlink )
        [g_SymlinkArrowImage drawInRect:icon_rect
                               fromRect:NSZeroRect
                              operation:NSCompositeSourceOver
                               fraction:1.0
                         respectFlipped:false
                                  hints:nil];
    
    
    if( m_Highlighted ) {
        // TODO: need to implement something like in Finder - draw rect with a color regaring current background color
        NSRect rc = self.bounds;
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        [[NSBezierPath bezierPathWithRect:NSInsetRect(rc,2,2)] fill];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

static bool     g_RowReadyToDrag = false;
static void*    g_MouseDownCarrier = nullptr;
static NSPoint  g_LastMouseDownPos = {};

- (void) mouseDown:(NSEvent *)event
{
    m_PermitFieldRenaming = m_Controller.selected && m_Controller.panelActive;
    
    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return;
    
    [m_Controller.briefView.panelView panelItem:my_index mouseDown:event];
    
    const auto lb_pressed = (NSEvent.pressedMouseButtons & 1) == 1;
    const auto local_point = [self convertPoint:event.locationInWindow fromView:nil];
    
    if( lb_pressed ) {
        g_RowReadyToDrag = true;
        g_MouseDownCarrier = (__bridge void*)self;
        g_LastMouseDownPos = local_point;
    }
}

- (void)mouseUp:(NSEvent *)event
{
    // used for delayed action to ensure that click was single, not double or more
    static atomic_ullong current_ticket = {0};
    static const nanoseconds delay = milliseconds( int(NSEvent.doubleClickInterval*1000) );
    
    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return;
    
    int click_count = (int)event.clickCount;
    if( click_count <= 1 && m_PermitFieldRenaming ) {
        uint64_t renaming_ticket = ++current_ticket;
        dispatch_to_main_queue_after(delay, [=]{
            if( renaming_ticket == current_ticket )
                [m_Controller.briefView.panelView panelItem:my_index fieldEditor:event];
        });
    }
    else if( click_count == 2 || click_count == 4 || click_count == 6 || click_count == 8 ) {
        // Handle double-or-four-etc clicks as double-click
        ++current_ticket; // to abort field editing
        [m_Controller.briefView.panelView panelItem:my_index dblClick:event];
    }
    
    m_PermitFieldRenaming = false;
    g_RowReadyToDrag = false;
    g_MouseDownCarrier = nullptr;
    g_LastMouseDownPos = {};
}

- (void) mouseDragged:(NSEvent *)event
{
    const auto max_drag_dist = 5.;
    if( g_RowReadyToDrag &&  g_MouseDownCarrier == (__bridge void*)self ) {
        const auto lp = [self convertPoint:event.locationInWindow fromView:nil];
        const auto dist = hypot(lp.x - g_LastMouseDownPos.x, lp.y - g_LastMouseDownPos.y);
        if( dist > max_drag_dist ) {
            const auto my_index = m_Controller.itemIndex;
            if( my_index < 0 )
                return;
            
            [m_Controller.briefView.panelView panelItem:my_index mouseDragged:event];
            g_RowReadyToDrag = false;
            g_MouseDownCarrier = nullptr;
            g_LastMouseDownPos = {};
        }
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)_event
{
    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return nil;

    return [m_Controller.briefView.panelView panelItem:my_index menuForForEvent:_event];    
}

- (void) setIcon:(NSImage *)icon
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
    const auto tm = panel::GetCurrentFilenamesTrimmingMode();
    NSDictionary *attrs = @{NSFontAttributeName: CurrentTheme().FilePanelsBriefFont(),
                            NSForegroundColorAttributeName: m_TextColor,
                            NSParagraphStyleAttributeName: ParagraphStyle(tm)};
    
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
    auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds];
    
    auto fi = FontGeometryInfo(CurrentTheme().FilePanelsBriefFont());
    
    text_segment_rect.size.height = fi.LineHeight();
    text_segment_rect.origin.y += 1;
    text_segment_rect.origin.x -= line_padding;
    
    _editor.frame = text_segment_rect;
    
    NSTextView *tv = _editor.documentView;
    tv.font = CurrentTheme().FilePanelsBriefFont();
    tv.textContainerInset = NSMakeSize(0, 0);
    tv.textContainer.lineFragmentPadding = line_padding;
    auto aa = tv.textContainerOrigin;
    
    
    [self addSubview:_editor];
}

- (void) setHighlighted:(bool)highlighted
{
    if( m_Highlighted != highlighted ) {
        m_Highlighted = highlighted;
        [self setNeedsDisplay:true];
    }
}

- (bool) validateDropHitTest:(id <NSDraggingInfo>)sender
{
    const auto bounds = self.bounds;
    const auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds];
    const auto text_rect = NSMakeRect(text_segment_rect.origin.x,
                                      m_LayoutConstants.font_baseline,
                                      text_segment_rect.size.width,
                                      0);
    const auto rc = [m_AttrString boundingRectWithSize:text_rect.size options:0 context:nil];
    const auto position = [self convertPoint:sender.draggingLocation fromView:nil];
    return position.x < text_rect.origin.x + max( rc.size.width, 32. );
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return NSDragOperationNone;
    
    if( [self validateDropHitTest:sender] ) {
        const auto op = [m_Controller.briefView.panelView panelItem:my_index operationForDragging:sender];
        if( op != NSDragOperationNone ) {
            self.isDropTarget = true;
            [self.superview draggingExited:sender];
            return op;
        }
    }
    
    self.isDropTarget = false;
    return [self.superview draggingEntered:sender];
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
    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return false;
    
    if( self.isDropTarget ) {
        self.isDropTarget = false;
        return [m_Controller.briefView.panelView panelItem:my_index performDragOperation:sender];
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
        if( m_IsDropTarget ) {
            self.layer.borderWidth = 1;
            self.layer.borderColor = CurrentTheme().FilePanelsGeneralDropBorderColor().CGColor;
        }
        else
            self.layer.borderWidth = 0;
    }
}

- (void) setLayoutConstants:(PanelBriefViewItemLayoutConstants)layoutConstants
{
    if( m_LayoutConstants != layoutConstants ) {
        m_LayoutConstants = layoutConstants;
        [self setNeedsDisplay:true];
    }
}

@end
