// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelListViewNameView.h"
#include <Utility/FontExtras.h>
#include <Utility/ObjCpp.h>
#include "../PanelView.h"
#include "../PanelViewPresentationSettings.h"
#include "PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewTableView.h"
#include <Panel/PanelViewFieldEditor.h>
#include <Panel/UI/TagsPresentation.h>

using namespace nc::panel;
using nc::utility::FontGeometryInfo;

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

@implementation PanelListViewNameView {
    NSString *m_Filename;
    NSImage *m_Icon;
    NSMutableAttributedString *m_AttrString;
    std::vector<nc::utility::Tags::Tag> m_Tags; // Consider a small vector of some sort
    bool m_PermitFieldRenaming;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)wantsDefaultClipping
{
    return false;
}

- (id)initWithFrame:(NSRect) [[maybe_unused]] _frameRect
{
    self = [super initWithFrame:NSRect()];
    if( self ) {
        m_PermitFieldRenaming = false;
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *) [[maybe_unused]] _theEvent
{
    /* really always??? */
    return true;
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *) [[maybe_unused]] _theEvent
{
    /* really always??? */
    return true;
}

- (void)setFilename:(NSString *)_filename andTags:(std::span<const nc::utility::Tags::Tag>)_tags
{
    m_Filename = _filename;
    m_Tags.assign(_tags.begin(), _tags.end());
    [self buildPresentation];
}

- (NSRect)calculateTextSegmentFromBounds:(NSRect)bounds andGeometry:(const PanelListViewGeometry &)g
{
    const int origin = g.FilenameOffsetInColumn();
    const auto tags_geom = TrailingTagsInplaceDisplay::Place(m_Tags);
    const auto width = bounds.size.width - origin - g.RightInset() - tags_geom.margin - tags_geom.width;

    return NSMakeRect(origin, 0, width, bounds.size.height);
}

- (void)drawRect:(NSRect) [[maybe_unused]] _dirtyRect
{
    auto row_view = nc::objc_cast<PanelListViewRowView>(self.superview);
    if( !row_view )
        return;
    if( !row_view.listView )
        return;

    const auto bounds = self.bounds;
    const auto geometry = row_view.listView.geometry;
    const auto is_symlink = row_view.item.IsSymlink();

    [row_view.rowBackgroundColor set];
    NSRectFill(self.bounds);
    [PanelListViewTableView drawVerticalSeparatorForView:self];

    const auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds andGeometry:geometry];
    const auto text_rect =
        NSMakeRect(text_segment_rect.origin.x, geometry.TextBaseLine(), text_segment_rect.size.width, 0);

    [m_AttrString drawWithRect:text_rect options:0];

    const auto icon_rect = NSMakeRect(geometry.LeftInset(),
                                      ((bounds.size.height - geometry.IconSize()) / 2.) + 0.5,
                                      geometry.IconSize(),
                                      geometry.IconSize());
    [m_Icon drawInRect:icon_rect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0
        respectFlipped:false
                 hints:nil];

    // Draw symlink arrow over an icon
    if( is_symlink )
        [g_SymlinkArrowImage drawInRect:icon_rect
                               fromRect:NSZeroRect
                              operation:NSCompositingOperationSourceOver
                               fraction:1.0
                         respectFlipped:false
                                  hints:nil];

    if( !m_Tags.empty() ) {
        const auto tags_geom = TrailingTagsInplaceDisplay::Place(m_Tags);
        TrailingTagsInplaceDisplay::Draw(text_segment_rect.origin.x + text_segment_rect.size.width + tags_geom.margin,
                                         bounds.size.height,
                                         m_Tags,
                                         row_view.tagAccentColor,
                                         row_view.rowBackgroundColor);
    }
}

- (void)buildPresentation
{
    PanelListViewRowView *row_view = static_cast<PanelListViewRowView *>(self.superview);
    if( !row_view )
        return;

    const auto tm = GetCurrentFilenamesTrimmingMode();
    NSDictionary *attrs = @{
        NSFontAttributeName: row_view.listView.font,
        NSForegroundColorAttributeName: row_view.rowTextColor,
        NSParagraphStyleAttributeName: ParagraphStyle(tm)
    };
    m_AttrString = [[NSMutableAttributedString alloc] initWithString:m_Filename attributes:attrs];

    auto vd = row_view.vd;
    if( !vd.highlight.empty() ) {
        const auto fn_len = static_cast<size_t>(m_Filename.length);
        const auto hl = vd.highlight.unpack();
        for( size_t i = 0; i != hl.count; ++i ) {
            if( hl.segments[i].offset < fn_len && hl.segments[i].offset + hl.segments[i].length <= fn_len ) {
                const auto range = NSMakeRange(hl.segments[i].offset, hl.segments[i].length);
                [m_AttrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
            }
        }
    }

    [self setNeedsDisplay:true];
}

- (void)setIcon:(NSImage *)icon
{
    if( m_Icon != icon ) {
        m_Icon = icon;

        [self setNeedsDisplay:true];
    }
}

- (NSImage *)icon
{
    return m_Icon;
}

- (PanelListViewRowView *)row
{
    return static_cast<PanelListViewRowView *>(self.superview);
}

- (PanelListView *)listView
{
    return self.row.listView;
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor
{
    const auto line_padding = 2.;

    const auto bounds = self.bounds;
    const auto geometry = self.row.listView.geometry;
    const auto font = self.row.listView.font;

    const auto text_segment_rect = [self calculateTextSegmentFromBounds:bounds andGeometry:geometry];
    const auto fi = FontGeometryInfo(font);

    // let the editor occupy the entire text segment and ensure that it is vertically centered within our view
    const auto rc =
        NSMakeRect(text_segment_rect.origin.x - line_padding,
                   geometry.TextBaseLine() - fi.Descent(),
                   text_segment_rect.size.width + 1, // cover for any roundings potentially caused by compressing
                   bounds.size.height - ((geometry.TextBaseLine() - fi.Descent()) * 2.));
    _editor.frame = rc;

    NSTextView *tv = _editor.documentView;
    tv.font = font;
    tv.textContainerInset = NSMakeSize(0, rc.size.height - fi.LineHeight());
    tv.textContainer.lineFragmentPadding = line_padding;

    [self addSubview:_editor];
}

static bool HasNoModifiers(NSEvent *_event)
{
    const auto m = _event.modifierFlags;
    const auto mask =
        NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand;
    return (m & mask) == 0;
}

- (void)mouseDown:(NSEvent *)event
{
    m_PermitFieldRenaming = self.row.selected && self.row.panelActive && HasNoModifiers(event);
    [super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
    //    used for delayed action to ensure that click was single, not double or more
    static std::atomic_ullong current_ticket = {0};
    static const std::chrono::nanoseconds delay = std::chrono::milliseconds(int(NSEvent.doubleClickInterval * 1000));

    const auto my_index = self.row.itemIndex;
    if( my_index < 0 )
        return;

    int click_count = static_cast<int>(event.clickCount);
    if( click_count <= 1 && m_PermitFieldRenaming ) {
        uint64_t renaming_ticket = ++current_ticket;
        dispatch_to_main_queue_after(delay, [=] {
            if( renaming_ticket == current_ticket )
                [self.listView.panelView panelItem:my_index fieldEditor:event];
        });
    }
    else if( click_count == 2 || click_count == 4 || click_count == 6 || click_count == 8 ) {
        // Handle double-or-four-etc clicks as double-click
        ++current_ticket; // to abort field editing
        [super mouseUp:event];
    }

    m_PermitFieldRenaming = false;
}

- (bool)dragAndDropHitTest:(NSPoint)_position
{
    const auto bounds = self.bounds;
    const auto geometry = self.row.listView.geometry;
    const auto text_rect = [self calculateTextSegmentFromBounds:bounds andGeometry:geometry];
    const auto rc = [m_AttrString boundingRectWithSize:text_rect.size options:0 context:nil];

    return _position.x <= std::max(rc.size.width, 32.) + text_rect.origin.x;
}

- (NSMenu *)menuForEvent:(NSEvent *)_event
{
    // TODO: mb switch to defaultMenu with a delegate instead of these shenanigans?
    return [self.row menuForEvent:_event];
}

@end
