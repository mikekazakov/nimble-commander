// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include "../PanelView.h"
#include "../PanelViewPresentationSettings.h"
#include "PanelBriefView.h"
#include "PanelBriefViewCollectionViewItem.h"
#include "PanelBriefViewItemCarrier.h"
#include <Base/dispatch_cpp.h>
#include <Panel/PanelViewFieldEditor.h>
#include <Panel/UI/TagsPresentation.h>

using namespace nc::panel;

static const auto g_SymlinkArrowImage =
    [[NSImage alloc] initWithData:[[NSDataAsset alloc] initWithName:@"AliasBadgeIcon"].data];

static NSParagraphStyle *ParagraphStyle(PanelViewFilenameTrimming _mode)
{
    static NSParagraphStyle *styles[3];
    static std::once_flag once;
    std::call_once(once, [] {
        NSMutableParagraphStyle *const p0 = [NSMutableParagraphStyle new];
        p0.alignment = NSTextAlignmentLeft;
        p0.lineBreakMode = NSLineBreakByTruncatingHead;
        p0.allowsDefaultTighteningForTruncation = false;
        styles[0] = p0;

        NSMutableParagraphStyle *const p1 = [NSMutableParagraphStyle new];
        p1.alignment = NSTextAlignmentLeft;
        p1.lineBreakMode = NSLineBreakByTruncatingTail;
        p1.allowsDefaultTighteningForTruncation = false;
        styles[1] = p1;

        NSMutableParagraphStyle *const p2 = [NSMutableParagraphStyle new];
        p2.alignment = NSTextAlignmentLeft;
        p2.lineBreakMode = NSLineBreakByTruncatingMiddle;
        p2.allowsDefaultTighteningForTruncation = false;
        styles[2] = p2;
    });

    switch( _mode ) {
        case PanelViewFilenameTrimming::Heading:
            return styles[0];
        case PanelViewFilenameTrimming::Trailing:
            return styles[1];
        case PanelViewFilenameTrimming::Middle:
            return styles[2];
        default:
            return nil;
    }
}

@implementation PanelBriefViewItemCarrier {
    NSColor *m_BackgroundColor;
    NSColor *m_TagAccentColor;
    NSColor *m_TextColor;
    NSString *m_Filename;
    NSImage *m_Icon;
    NSMutableAttributedString *m_AttrString;
    PanelBriefViewItemLayoutConstants m_LayoutConstants;
    __weak PanelBriefViewItem *m_Controller;
    nc::panel::data::QuickSearchHiglight m_QSHighlight;
    bool m_Highlighted;
    bool m_PermitFieldRenaming;
    bool m_IsDropTarget;
    bool m_IsSymlink;
}

@synthesize backgroundColor = m_BackgroundColor;
@synthesize tagAccentColor = m_TagAccentColor;
@synthesize filename = m_Filename;
@synthesize layoutConstants = m_LayoutConstants;
@synthesize controller = m_Controller;
@synthesize qsHighlight = m_QSHighlight;
@synthesize highlighted = m_Highlighted;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.autoresizingMask = NSViewNotSizable;
        self.autoresizesSubviews = false;
        self.postsFrameChangedNotifications = false;
        self.postsBoundsChangedNotifications = false;
        m_TextColor = NSColor.blackColor;
        m_Filename = @"";
        m_QSHighlight = {};
        m_PermitFieldRenaming = false;
        m_Highlighted = false;
        m_IsDropTarget = false;
        m_IsSymlink = false;
        m_AttrString = [[NSMutableAttributedString alloc] initWithString:@"" attributes:nil];

        [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];
    }
    return self;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)wantsDefaultClipping
{
    return false;
}

- (void)setFrameOrigin:(NSPoint)_new_origin
{
    if( NSEqualPoints(_new_origin, self.frame.origin) )
        return;
    [super setFrameOrigin:_new_origin];
    [self setNeedsDisplay:true];
}

- (void)setFrameSize:(NSSize)_new_size
{
    if( NSEqualSizes(_new_size, self.frame.size) )
        return;
    [super setFrameSize:_new_size];
    [self setNeedsDisplay:true];
}

- (void)setFrame:(NSRect)_new_frame
{
    if( NSEqualRects(_new_frame, self.frame) )
        return;
    [super setFrame:_new_frame];
    [self setNeedsDisplay:true];
}

- (NSRect)calculateTextSegmentFromBounds:(NSRect)bounds
{
    const int origin = m_LayoutConstants.icon_size ? (2 * m_LayoutConstants.inset_left) + m_LayoutConstants.icon_size
                                                   : m_LayoutConstants.inset_left;
    const auto tags = m_Controller.item.Tags();
    const auto tags_geom = TrailingTagsInplaceDisplay::Place(tags);
    const auto width = bounds.size.width - origin - m_LayoutConstants.inset_right - tags_geom.margin - tags_geom.width;
    return NSMakeRect(origin, 0, width, bounds.size.height);
}

static NSColor *Blend(NSColor *_front, NSColor *_back)
{
    const auto alpha = _front.alphaComponent;
    if( alpha == 1. )
        return _front;
    if( alpha == 0. )
        return _back;

    const auto cs = NSColorSpace.genericRGBColorSpace;
    _front = [_front colorUsingColorSpace:cs];
    _back = [_back colorUsingColorSpace:cs];
    const auto r = (_front.redComponent * alpha) + (_back.redComponent * (1. - alpha));
    const auto g = (_front.greenComponent * alpha) + (_back.greenComponent * (1. - alpha));
    const auto b = (_front.blueComponent * alpha) + (_back.blueComponent * (1. - alpha));
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.];
}

- (NSColor *)deduceBackground:(NSRect)_bounds
{
    const bool is_odd = int(self.frame.origin.y / _bounds.size.height) % 2;
    auto c = is_odd ? nc::CurrentTheme().FilePanelsBriefRegularOddRowBackgroundColor()
                    : nc::CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor();

    if( m_BackgroundColor ) {
        const auto alpha = m_BackgroundColor.alphaComponent;
        if( alpha == 1. )
            return m_BackgroundColor;
        return Blend(m_BackgroundColor, c);
    }
    else {
        return c;
    }
}

- (void)drawRect:(NSRect) [[maybe_unused]] _dirty_rect
{
    const auto bounds = self.bounds;
    const auto context = NSGraphicsContext.currentContext.CGContext;

    NSColor *background = [self deduceBackground:bounds];
    CGContextSetFillColorWithColor(context, background.CGColor);
    CGContextFillRect(context, bounds);

    const auto grid_color = nc::CurrentTheme().FilePanelsBriefGridColor();
    CGContextSetFillColorWithColor(context, grid_color.CGColor);
    CGContextFillRect(context, NSMakeRect(bounds.size.width - 1, 0, 1, bounds.size.height));

    const auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds];
    /* using additional 0.5 width to eliminame situations, when drawWithRect trims string due to,
    rounding/rendering side effects */
    const auto text_rect =
        NSMakeRect(text_segment_rect.origin.x, m_LayoutConstants.font_baseline, text_segment_rect.size.width + 0.5, 0);
    [m_AttrString drawWithRect:text_rect options:0];

    const auto icon_rect = NSMakeRect(m_LayoutConstants.inset_left,
                                      ((bounds.size.height - m_LayoutConstants.icon_size) / 2.) + 0.5,
                                      m_LayoutConstants.icon_size,
                                      m_LayoutConstants.icon_size);
    [m_Icon drawInRect:icon_rect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0
        respectFlipped:false
                 hints:nil];

    // Draw symlink arrow over an icon
    if( m_IsSymlink )
        [g_SymlinkArrowImage drawInRect:icon_rect
                               fromRect:NSZeroRect
                              operation:NSCompositingOperationSourceOver
                               fraction:1.0
                         respectFlipped:false
                                  hints:nil];

    if( const auto tags = m_Controller.item.Tags(); !tags.empty() ) {
        const auto tags_geom = TrailingTagsInplaceDisplay::Place(tags);
        TrailingTagsInplaceDisplay::Draw(text_segment_rect.origin.x + text_segment_rect.size.width + tags_geom.margin,
                                         bounds.size.height,
                                         tags,
                                         m_TagAccentColor,
                                         background);
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *) [[maybe_unused]] _event
{
    /* really always??? */
    return true;
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *) [[maybe_unused]] _event
{
    /* really always??? */
    return true;
}

static bool g_RowReadyToDrag = false;
static void *g_MouseDownCarrier = nullptr;
static NSPoint g_LastMouseDownPos = {};

static bool HasNoModifiers(NSEvent *_event)
{
    const auto m = _event.modifierFlags;
    const auto mask =
        NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand;
    return (m & mask) == 0;
}

- (void)mouseDown:(NSEvent *)_event
{
    const NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    if( !NSPointInRect(local_point, self.bounds) ) {
        // In case of rapid mouse clicks and reloading items of NSCollectionView at the same time it's possible to end
        // up with a situation when mouse events are incoming to the view which is no longer relevant. Sometimes it's
        // possible to partially salvage this situation by manually re-routing the event to the correct view.
        NSView *ht_view = [self.window.contentView hitTest:_event.locationInWindow];
        if( ht_view != nil && ht_view != self )
            [ht_view mouseDown:_event];
        return;
    }

    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return;

    m_PermitFieldRenaming = m_Controller.selected && m_Controller.panelActive && HasNoModifiers(_event);

    [m_Controller.briefView.panelView panelItem:my_index mouseDown:_event];

    const bool lb_pressed = NSEvent.pressedMouseButtons == 1;

    if( lb_pressed ) {
        g_RowReadyToDrag = true;
        g_MouseDownCarrier = (__bridge void *)self;
        g_LastMouseDownPos = local_point;
    }
}

- (void)mouseUp:(NSEvent *)_event
{
    // used for delayed action to ensure that click was single, not double or more
    static std::atomic_ullong current_ticket = {0};
    static const std::chrono::nanoseconds delay = std::chrono::milliseconds(int(NSEvent.doubleClickInterval * 1000));

    const NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    if( !NSPointInRect(local_point, self.bounds) ) {
        // In case of rapid mouse clicks and reloading items of NSCollectionView at the same time it's possible to end
        // up with a situation when mouse events are incoming to the view which is no longer relevant. Sometimes it's
        // possible to partially salvage this situation by manually re-routing the event to the correct view.
        NSView *ht_view = [self.window.contentView hitTest:_event.locationInWindow];
        if( ht_view != nil && ht_view != self )
            [ht_view mouseUp:_event];
        return;
    }

    const auto my_index = m_Controller.itemIndex;
    if( my_index < 0 )
        return;

    int click_count = static_cast<int>(_event.clickCount);
    if( click_count <= 1 && m_PermitFieldRenaming ) {
        uint64_t renaming_ticket = ++current_ticket;
        dispatch_to_main_queue_after(delay, [=] {
            if( renaming_ticket == current_ticket )
                [m_Controller.briefView.panelView panelItem:my_index fieldEditor:_event];
        });
    }
    else if( click_count == 2 || click_count == 4 || click_count == 6 || click_count == 8 ) {
        // Handle double-or-four-etc clicks as double-click
        ++current_ticket; // to abort field editing
        [m_Controller.briefView.panelView panelItem:my_index dblClick:_event];
    }

    m_PermitFieldRenaming = false;
    g_RowReadyToDrag = false;
    g_MouseDownCarrier = nullptr;
    g_LastMouseDownPos = {};
}

- (void)mouseDragged:(NSEvent *)event
{
    const auto max_drag_dist = 10.;
    if( g_RowReadyToDrag && g_MouseDownCarrier == (__bridge void *)self ) {
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

- (NSImage *)icon
{
    return m_Icon;
}

- (void)setIcon:(NSImage *)icon
{
    if( m_Icon != icon ) {
        m_Icon = icon;
        [self setNeedsDisplay:true];
    }
}

- (NSColor *)filenameColor
{
    return m_TextColor;
}

- (void)setFilenameColor:(NSColor *)filenameColor
{
    if( m_TextColor != filenameColor ) {
        m_TextColor = filenameColor;
        [m_AttrString addAttribute:NSForegroundColorAttributeName
                             value:m_TextColor
                             range:NSMakeRange(0, m_AttrString.length)];
        [self setNeedsDisplay:true];
    }
}

- (void)setBackgroundColor:(NSColor *)background
{
    if( m_BackgroundColor != background ) {
        m_BackgroundColor = background;
        [self setNeedsDisplay:true];
    }
}

- (void)setFilename:(NSString *)filename
{
    if( m_Filename != filename ) {
        m_Filename = filename;
        [self buildTextAttributes];
    }
}

- (void)buildTextAttributes
{
    const auto tm = GetCurrentFilenamesTrimmingMode();
    NSDictionary *attrs = @{
        NSFontAttributeName: nc::CurrentTheme().FilePanelsBriefFont(),
        NSForegroundColorAttributeName: m_TextColor,
        NSParagraphStyleAttributeName: ParagraphStyle(tm)
    };

    m_AttrString = [[NSMutableAttributedString alloc] initWithString:m_Filename attributes:attrs];

    if( !m_QSHighlight.empty() ) {
        const auto hl = m_QSHighlight.unpack();
        const auto fn_len = static_cast<size_t>(m_Filename.length);
        for( size_t i = 0; i != hl.count; ++i ) {
            if( hl.segments[i].offset < fn_len && hl.segments[i].offset + hl.segments[i].length <= fn_len ) {
                const auto range = NSMakeRange(hl.segments[i].offset, hl.segments[i].length);
                [m_AttrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
            }
        }
    }
    [self setNeedsDisplay:true];
}

- (void)setQsHighlight:(nc::panel::data::QuickSearchHiglight)qsHighlight
{
    if( m_QSHighlight != qsHighlight ) {
        m_QSHighlight = qsHighlight;
        [m_AttrString removeAttribute:NSUnderlineStyleAttributeName range:NSMakeRange(0, m_AttrString.length)];
        if( !m_QSHighlight.empty() ) {
            const auto hl = m_QSHighlight.unpack();
            const auto fn_len = static_cast<size_t>(m_Filename.length);
            for( size_t i = 0; i != hl.count; ++i ) {
                if( hl.segments[i].offset < fn_len && hl.segments[i].offset + hl.segments[i].length <= fn_len ) {
                    const auto range = NSMakeRange(hl.segments[i].offset, hl.segments[i].length);
                    [m_AttrString addAttribute:NSUnderlineStyleAttributeName
                                         value:@(NSUnderlineStyleSingle)
                                         range:range];
                }
            }
        }
        [self setNeedsDisplay:true];
    }
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor
{
    const auto line_padding = 2.;

    const auto bounds = self.bounds;
    auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds];
    auto fi = nc::utility::FontGeometryInfo(nc::CurrentTheme().FilePanelsBriefFont());

    // let the editor occupy the entire text segment and ensure that it is vertically centered within our view
    text_segment_rect.origin.y = m_LayoutConstants.font_baseline - fi.Descent();
    text_segment_rect.origin.x -= line_padding;
    text_segment_rect.size.height = bounds.size.height - text_segment_rect.origin.y * 2.;
    text_segment_rect.size.width += 1.; // cover for any roundings potentially caused by compressing
    _editor.frame = text_segment_rect;

    NSTextView *tv = _editor.documentView;
    tv.font = nc::CurrentTheme().FilePanelsBriefFont();
    tv.textContainerInset = NSMakeSize(0, text_segment_rect.size.height - fi.LineHeight());
    tv.textContainer.lineFragmentPadding = line_padding;

    [self addSubview:_editor];
}

- (void)setHighlighted:(bool)highlighted
{
    if( m_Highlighted != highlighted ) {
        m_Highlighted = highlighted;
        [self updateBorder];
    }
}

- (bool)validateDropHitTest:(id<NSDraggingInfo>)sender
{
    const auto bounds = self.bounds;
    const auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds];
    const auto text_rect =
        NSMakeRect(text_segment_rect.origin.x, m_LayoutConstants.font_baseline, text_segment_rect.size.width, 0);
    const auto rc = [m_AttrString boundingRectWithSize:text_rect.size options:0 context:nil];
    const auto position = [self convertPoint:sender.draggingLocation fromView:nil];
    return position.x < text_rect.origin.x + std::max(rc.size.width, 32.);
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
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

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    if( self.isDropTarget ) {
        self.isDropTarget = false;
    }
    else {
        [self.superview draggingExited:sender];
    }
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>) [[maybe_unused]] sender
{
    // possibly add some checking stage here later
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
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

- (bool)isDropTarget
{
    return m_IsDropTarget;
}

- (void)setIsDropTarget:(bool)isDropTarget
{
    if( m_IsDropTarget != isDropTarget ) {
        m_IsDropTarget = isDropTarget;
        [self updateBorder];
    }
}

- (void)updateBorder
{
    if( m_IsDropTarget || m_Highlighted ) {
        self.layer.borderWidth = 1;
        self.layer.borderColor = nc::CurrentTheme().FilePanelsGeneralDropBorderColor().CGColor;
    }
    else
        self.layer.borderWidth = 0;
}

- (void)setLayoutConstants:(PanelBriefViewItemLayoutConstants)layoutConstants
{
    if( m_LayoutConstants != layoutConstants ) {
        m_LayoutConstants = layoutConstants;
        [self setNeedsDisplay:true];
    }
}

- (bool)isSymlink
{
    return m_IsSymlink;
}

- (void)setIsSymlink:(bool)isSymlink
{
    if( m_IsSymlink != isSymlink ) {
        m_IsSymlink = isSymlink;
        [self setNeedsDisplay:true];
    }
}

@end
