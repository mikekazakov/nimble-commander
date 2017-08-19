#include <Utility/FontExtras.h>
#include <VFS/Native.h>
#include "../MainWindowController.h"
#include "PanelController+DragAndDrop.h"
#include "MainWindowFilePanelState.h"
#include "PanelDataItemVolatileData.h"
#include "FilesDraggingSource.h"
#include "PanelData.h"

using namespace nc::panel;

/*//////////////////////////////////////////////////////////////////////////////////////////////////
This is the most obscure Cocoa usage in NC.
 
Test cases to check if it works:
- drag and drop few images into Messages.app.
  should show them all in outgoing message.
- drag and drop few images/files into Mail.app in new letter.
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

static NSArray* BuildImageComponentsForItem(PanelDraggingItem* _item)
{
    if( _item == nil || ! _item.item )
        return nil;
    auto item = _item.item;
    
    NSDraggingImageComponent *imageComponent;
    NSMutableArray *components = [NSMutableArray arrayWithCapacity:2];
    
    static NSFont *font = [NSFont systemFontOfSize:13];
    static FontGeometryInfo font_info{ (__bridge CTFontRef) font };
    
    NSImage *icon_image;
    if(item.Host()->IsNativeFS())
        icon_image = [NSWorkspace.sharedWorkspace iconForFile:[NSString stringWithUTF8StdString:item.Path()]];
    else
        icon_image = [NSWorkspace.sharedWorkspace iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    
    [icon_image setSize:NSMakeSize(font_info.LineHeight(), font_info.LineHeight())];
    imageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
    imageComponent.frame = NSMakeRect(0, 0, font_info.LineHeight(), font_info.LineHeight());
    imageComponent.contents = icon_image;
    [components addObject:imageComponent];
    
    
    double label_width = 250;
    
    NSImage *label_image = [[NSImage alloc] initWithSize:CGSizeMake(label_width, font_info.LineHeight())];
    [label_image lockFocus];
    
    
    NSShadow *label_shadow = [NSShadow new];
    label_shadow.shadowBlurRadius = 1;
    label_shadow.shadowColor = [NSColor colorWithDeviceRed:0.83 green:0.93 blue:1 alpha:1];
    label_shadow.shadowOffset = NSMakeSize(0, -1);
    
    NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new];
    item_text_pstyle.alignment = NSLeftTextAlignment;
    item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    NSDictionary *attributes = @{ NSFontAttributeName: font,
                                  NSForegroundColorAttributeName: NSColor.blackColor,
                                  NSParagraphStyleAttributeName: item_text_pstyle,
                                  NSShadowAttributeName: label_shadow };
    
    NSString *itemName = [NSString stringWithUTF8StdString:item.Filename()];
    
    [itemName drawWithRect:NSMakeRect(0, font_info.Descent(), label_width, font_info.LineHeight())
                   options:0
                attributes:attributes];
    
    [label_image unlockFocus];
    imageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey];
    imageComponent.frame = NSMakeRect(font_info.LineHeight() + 7, 0, label_width, font_info.LineHeight());
    imageComponent.contents = label_image;
    [components addObject:imageComponent];
    
    return components;
}


@implementation PanelController (DragAndDrop)

static vector<VFSListingItem> ComposeItemsForDragging( int _sorted_pos, const data::Model &_data )
{
    const auto dragged_item = _data.EntryAtSortPosition(_sorted_pos);
    if( !dragged_item || dragged_item.IsDotDot() )
        return {};
    
    const auto dragged_item_vd = _data.VolatileDataAtSortPosition(_sorted_pos);
    
    vector<VFSListingItem> items;
    
    if( dragged_item_vd.is_selected() == false)
        items.emplace_back(dragged_item); // drag only clicked item
    else
        items = _data.SelectedEntries(); // drag all selected items

    return items;
}

- (void) initiateDragFromView:(NSView*)_view itemNo:(int)_sort_pos byEvent:(NSEvent *)_event
{
    const auto vfs_items = ComposeItemsForDragging(_sort_pos, self.data);
    if( vfs_items.empty() )
        return;
    
    const auto all_items_native = all_of(begin(vfs_items), end(vfs_items), [](auto &i){
        return i.Host()->IsNativeFS();
    });
    auto dragging_source = [[FilesDraggingSource alloc] initWithSourceController:self];
    auto drag_items = [[NSMutableArray alloc] initWithCapacity:vfs_items.size()];
    
    NSPoint dragPosition = [_view convertPoint:_event.locationInWindow fromView:nil];
    dragPosition.x -= 16;
    dragPosition.y -= 16;

    const auto pasteboard_types = all_items_native ?
        @[FilesDraggingSource.fileURLsPromiseDragUTI,
//        FilesDraggingSource.filenamesPBoardDragUTI,
//        FilesDraggingSource.fileURLsDragUTI,
          FilesDraggingSource.privateDragUTI] :
        @[FilesDraggingSource.fileURLsPromiseDragUTI,
          FilesDraggingSource.privateDragUTI];

    for( auto &i: vfs_items ) {
        // dragging item itself
        auto pb_item = [[PanelDraggingItem alloc] initWithItem:i];
        [pb_item setDataProvider:dragging_source forTypes:pasteboard_types];
        [dragging_source addItem:pb_item];
    
        // visual appearance of a dragging item
        auto drag_item = [[NSDraggingItem alloc] initWithPasteboardWriter:pb_item];
        drag_item.draggingFrame = NSMakeRect(dragPosition.x, dragPosition.y, 32, 32);

        __weak PanelDraggingItem *weak_pb_item = pb_item;
        drag_item.imageComponentsProvider = ^{
            return BuildImageComponentsForItem((PanelDraggingItem *)weak_pb_item);
        };
        
        [drag_items addObject:drag_item];
        dragPosition.y -= 16;
    }
    
    auto session = [_view beginDraggingSessionWithItems:drag_items
                                                  event:_event
                                                 source:dragging_source];
    if( session ) {
        [dragging_source writeURLsPBoard:session.draggingPasteboard];
        [NSApp preventWindowOrdering];
    }
}

@end
