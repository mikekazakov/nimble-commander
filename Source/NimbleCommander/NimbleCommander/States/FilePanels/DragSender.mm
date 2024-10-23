// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DragSender.h"
#include "FilesDraggingSource.h"
#include "PanelController.h"
#include <Panel/PanelData.h>
#include <Panel/PanelDataItemVolatileData.h>
#include <Utility/FontExtras.h>
#include <VFS/Native.h>
#include <cmath>

/*//////////////////////////////////////////////////////////////////////////////////////////////////
This is the most obscure Cocoa usage in NC.

Test cases to check if it works:
- drag and drop few images into Messages.app.
  it should show them all in an outgoing message.
- drag and drop a few images/files into Mail.app in a new letter.
  should work as expected
- drag and drop few videos/tracks into VLC player in:
  1) playlist
  2) media library
  should work everywhere as expected
- drag and drop few files into Finder.app.
  should work everywhere as expected

Check table:
 target app        drag from native      drag from vfs
 Messages.app             +                      +
 Mail.app                 +                      -
 VLC.app                  +                      -
 Finder.app               +                      +
 Firefox(drag to Gdrive)  +                      -
 Safari(drag to Gdrive)   +                      -
 Chrome(drag to Gdrive)   +                      -


*///////////////////////////////////////////////////////////////////////////////////////////////////

namespace nc::panel {

static NSArray *BuildImageComponentsForItem(PanelDraggingItem *_item);

DragSender::DragSender(PanelController *_panel, IconCallback _icon_callback, nc::vfs::NativeHost &_native_vfs)
    : m_Panel(_panel), m_IconCallback(std::move(_icon_callback)), m_NativeHost(_native_vfs)
{
    assert(m_Panel != nullptr);
    assert(m_IconCallback != nullptr);
}

DragSender::~DragSender() = default;

void DragSender::Start(NSView *_from_view, NSEvent *_via_event, int _dragged_panel_item_sorted_index)
{
    static const auto pasteboard_types =
        @[FilesDraggingSource.fileURLsPromiseDragUTI, FilesDraggingSource.privateDragUTI];

    const auto vfs_items = Impl::ComposeItemsForDragging(_dragged_panel_item_sorted_index, m_Panel.data);
    if( vfs_items.empty() )
        return;

    auto position = [_from_view convertPoint:_via_event.locationInWindow fromView:nil];
    position.x -= 16;
    position.y -= 16;

    const auto dragging_source = [[FilesDraggingSource alloc] initWithSourceController:m_Panel nativeHost:m_NativeHost];
    const auto drag_items = [[NSMutableArray alloc] initWithCapacity:vfs_items.size()];
    for( const auto &item : vfs_items ) {
        // dragging item itself
        auto pasterboard_item = [[PanelDraggingItem alloc] initWithItem:item];
        [pasterboard_item setDataProvider:dragging_source forTypes:pasteboard_types];
        pasterboard_item.icon = m_IconCallback(item);

        [dragging_source addItem:pasterboard_item];

        // visual appearance of a dragging item
        auto drag_item = [[NSDraggingItem alloc] initWithPasteboardWriter:pasterboard_item];
        drag_item.draggingFrame = NSMakeRect(std::floor(position.x), std::floor(position.y), 32, 32);

        __weak PanelDraggingItem *weak_pb_item = pasterboard_item;
        drag_item.imageComponentsProvider = ^{
          return BuildImageComponentsForItem(static_cast<PanelDraggingItem *>(weak_pb_item));
        };

        [drag_items addObject:drag_item];
        position.y -= 16;
    }

    const auto session = [_from_view beginDraggingSessionWithItems:drag_items event:_via_event source:dragging_source];
    if( session ) {
        [dragging_source writeURLsPBoard:session.draggingPasteboard];
        [NSApp preventWindowOrdering];
    }
}

std::vector<VFSListingItem> DragSender::Impl::ComposeItemsForDragging(int _sorted_pos, const data::Model &_data)
{
    const auto dragged_item = _data.EntryAtSortPosition(_sorted_pos);
    if( !dragged_item || dragged_item.IsDotDot() )
        return {};

    const auto dragged_item_vd = _data.VolatileDataAtSortPosition(_sorted_pos);

    std::vector<VFSListingItem> items;

    if( !dragged_item_vd.is_selected() )
        items.emplace_back(dragged_item); // drag only clicked item
    else
        items = _data.SelectedEntriesSorted(); // drag all selected items

    return items;
}

static NSDraggingImageComponent *BuildIconComponent(PanelDraggingItem *_item)
{
    if( _item.icon == nil )
        return nil;
    const auto icon_image = static_cast<NSImage *>(_item.icon.copy);
    const auto key = NSDraggingImageComponentIconKey;
    icon_image.size = NSMakeSize(16, 16);

    const auto component = [NSDraggingImageComponent draggingImageComponentWithKey:key];
    component.frame = NSMakeRect(0, 0, 16, 16);
    component.contents = icon_image;

    return component;
}

static void DrawRoundedRect(NSImage *_context)
{
    const auto sz = _context.size;
    const auto r = std::floor(sz.height / 2);
    const auto rect = NSMakeRect(0, 0, sz.width, sz.height);
    const auto bezier_path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r];
    [NSColor.blueColor set];
    [bezier_path fill];
}

static NSDraggingImageComponent *
BuildLabelComponent(PanelDraggingItem *_item, NSFont *_font, const utility::FontGeometryInfo &_fi)
{
    const auto key = NSDraggingImageComponentLabelKey;
    const auto max_label_width = 250.;
    const auto height = _fi.LineHeight();

    static const auto attributes = [&] {
        NSMutableParagraphStyle *const item_text_pstyle = [NSMutableParagraphStyle new];
        item_text_pstyle.alignment = NSTextAlignmentLeft;
        item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        const auto attrs = @{
            NSFontAttributeName: _font,
            NSForegroundColorAttributeName: NSColor.whiteColor,
            NSParagraphStyleAttributeName: item_text_pstyle
        };
        return attrs;
    }();

    const auto filename = _item.item.FilenameNS();
    const auto estimated_label_bounds = [filename boundingRectWithSize:NSMakeSize(max_label_width, 0)
                                                               options:0
                                                            attributes:attributes];
    const auto label_width = std::min(max_label_width, std::ceil(estimated_label_bounds.size.width)) + height;

    const auto label_image = [[NSImage alloc] initWithSize:CGSizeMake(label_width, height)];

    [label_image lockFocus];
    DrawRoundedRect(label_image);
    [filename drawWithRect:NSMakeRect(std::floor(height / 2), _fi.Descent(), label_width - height, 0)
                   options:0
                attributes:attributes];
    [label_image unlockFocus];

    const auto label_component = [NSDraggingImageComponent draggingImageComponentWithKey:key];
    label_component.frame = NSMakeRect(17, 0, label_image.size.width, label_image.size.height);
    label_component.contents = label_image;

    return label_component;
}

static NSArray *BuildImageComponentsForItem(PanelDraggingItem *_item)
{
    static const auto font = [NSFont systemFontOfSize:13];
    static const utility::FontGeometryInfo font_info{(__bridge CTFontRef)font};

    if( _item == nil || !_item.item )
        return nil;

    const auto label_component = BuildLabelComponent(_item, font, font_info);
    assert(label_component != nil);

    const auto icon_component = BuildIconComponent(_item);
    if( icon_component != nil )
        return @[icon_component, label_component];
    else
        return @[label_component];
}

} // namespace nc::panel
