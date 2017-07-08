#include <Utility/FontExtras.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <Operations/Linkage.h>
#include "../MainWindowController.h"
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include <NimbleCommander/Operations/OperationsController.h>
#include "PanelController+DragAndDrop.h"
#include "MainWindowFilePanelState.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "PanelAux.h"
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

static bool DraggingIntoFoldersAllowed()
{
    return GlobalConfig().GetBool( "filePanel.general.allowDraggingIntoFolders" );
}

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


static map<string, vector<string>> LayoutArraysOfURLsByDirectories(NSArray *_file_urls)
{
    if(!_file_urls)
        return {};
    map<string, vector<string>> files; // directory/ -> [filename1, filename2, ...]
    for(NSURL *url in _file_urls) {
        if( !objc_cast<NSURL>(url) ) continue; // guard agains malformed input data
        path source_path = url.path.fileSystemRepresentation;
        string root = source_path.parent_path().native() + "/";
        files[root].emplace_back(source_path.filename().native());
    }
    return files;
}

// consumes result of code above
static vector<VFSListingItem> FetchVFSListingsItemsFromDirectories( const map<string, vector<string>>& _input, VFSHost& _host)
{
    vector<VFSListingItem> source_items;
    for( auto &dir: _input ) {
        vector<VFSListingItem> items_for_dir;
        if( _host.FetchFlexibleListingItems(dir.first, dir.second, 0, items_for_dir, nullptr) == VFSError::Ok )
            move( begin(items_for_dir), end(items_for_dir), back_inserter(source_items) );
    }
    return source_items;
}

static NSDragOperation BuildOperationMaskForLocal( FilesDraggingSource *_source,
                                                   const VFSPath &_destination )
{
    const auto kbd = NSEvent.modifierFlags;
    if( _destination.Host()->IsNativeFS() && _source.areAllHostsNative ) {
        // special treatment for native fs'es
        const auto &fs_man = NativeFSManager::Instance();
        const auto v1 = fs_man.VolumeFromPathFast( _destination.Path() );
        const auto v2 = fs_man.VolumeFromPathFast( _source.items.front().item.Directory() );
        const auto same_native_fs = (v1 != nullptr && v1 == v2);
        if( same_native_fs ) {
            if( kbd & NSCommandKeyMask )
                return NSDragOperationMove;
            else if( kbd & NSAlternateKeyMask )
                return NSDragOperationCopy;
            else if( kbd & NSControlKeyMask )
                return NSDragOperationLink;
            else
                return NSDragOperationMove;
        }
        else {
            if( kbd & NSCommandKeyMask )
                return _source.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
            else if( kbd & NSAlternateKeyMask )
                return NSDragOperationCopy;
            else if( kbd & NSControlKeyMask )
                return NSDragOperationLink;
            else
                return NSDragOperationCopy;
        }
    }
    else {
        // if src or dst is on VFS
        if( _source.commonHost == _destination.Host() ) {
            if( kbd & NSAlternateKeyMask )
                return NSDragOperationCopy;
            else
                return _source.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
        }
        else {
            if( kbd & NSCommandKeyMask )
                return _source.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
            else
                return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

@implementation PanelController (DragAndDrop)

////////////////////////////////////////////////////////////////////////////////////////////////////
//
//                              Drag Source Section
//
////////////////////////////////////////////////////////////////////////////////////////////////////
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

////////////////////////////////////////////////////////////////////////////////////////////////////
//
//                              Drop Target Section
//
////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSArray*) acceptedDragAndDropTypes
{
    // why don't we support filenames pasteboard?
    return @[FilesDraggingSource.fileURLsPromiseDragUTI,
             FilesDraggingSource.fileURLsDragUTI,
             FilesDraggingSource.privateDragUTI];
}

static int CountAcceptableDraggingItemsExt( id<NSDraggingInfo> _sender, NSString *_type )
{
    __block int urls_amount = 0;
    [_sender enumerateDraggingItemsWithOptions:0
                                       forView:nil
                                       classes:@[NSPasteboardItem.class]
                                 searchOptions:@{}
                                    usingBlock:^(NSDraggingItem *draggingItem, NSInteger, BOOL *) {
                                        if( auto i = objc_cast<NSPasteboardItem>(draggingItem.item))
                                            if( [i.types containsObject:_type] )
                                                urls_amount++;
                                    }];
    return urls_amount;
}

- (VFSPath) composeDestinationForDrag:(id <NSDraggingInfo>)sender
                        overPanelItem:(const VFSListingItem&)_item // may be nullptr
{
    const auto dragging_over_dir = _item && _item.IsDir();
    
    if( dragging_over_dir ) {
        if( _item.IsDotDot() ) {
            if( !self.isUniform )
                return {};
            path p = self.currentDirectoryPath;
            p.remove_filename();
            if(p.empty())
                p = "/";
            return {self.vfs, (p.parent_path() / "/").native()};
        }
        else {
            auto p = path(_item.Directory()) / _item.Filename() / "/";
            return {_item.Host(), p.native()};
        }
    }
    else {
        if( !self.isUniform )
            return {};
        return {self.vfs, self.currentDirectoryPath};
    }
}

static void UpdateValidDropNumber( id <NSDraggingInfo> _dragging,
                                   int _valid_number,
                                   NSDragOperation _operation )
{
    // prevent setting of a same value to DraggingInfo, since it causes weird blinking
    static __weak id last_updated = nil;
    static int last_set = 0;
    
    if( last_updated == _dragging ) {
        if( last_set != _valid_number ) {
            last_set = _valid_number;
            if( _operation != NSDragOperationNone )
                _dragging.numberOfValidItemsForDrop = last_set;
        }
    }
    else {
        last_updated = _dragging;
        last_set = _valid_number;
        if( _operation != NSDragOperationNone )
            _dragging.numberOfValidItemsForDrop = last_set;
    }
}

- (NSDragOperation) validateDraggingOperation:(id <NSDraggingInfo>)_dragging
                                 forPanelItem:(int)_sorted_index // -1 means "whole" panel
{
    static const auto url_promise_uti = FilesDraggingSource.fileURLsPromiseDragUTI;
    static const auto url_uti = FilesDraggingSource.fileURLsDragUTI;
    
    const auto dragging_over_item = self.data.EntryAtSortPosition(_sorted_index);
    const auto dragging_over_dir = dragging_over_item && dragging_over_item.IsDir();
    if( dragging_over_item ) {
        if( dragging_over_dir && !DraggingIntoFoldersAllowed() ) // <-- optimize this !!
            return NSDragOperationNone;
        if( !dragging_over_dir )
            return NSDragOperationNone;
    }
    
    const auto destination = [self composeDestinationForDrag:_dragging
                                               overPanelItem:dragging_over_item];
    int valid_items = 0;
    NSDragOperation result = NSDragOperationNone;
        
    if( destination && destination.Host()->IsWritable()) {
        if( auto source = objc_cast<FilesDraggingSource>(_dragging.draggingSource) ) {
            // drag is from some other panel
            valid_items = (int)source.items.size();
            if( source.sourceController == self && !dragging_over_dir )
                result = NSDragOperationNone; // we can't drag into the same dir on the same panel
            else // complex logic with keyboard modifiers
                result = BuildOperationMaskForLocal(source, destination);
            
            // check that we dont drag an item to the same folder in other panel
            if( any_of(begin(source.items), end(source.items), [&](auto &_i) {
                return _i.item.Directory() == destination.Path() &&
                       _i.item.Host() == destination.Host();
                }) )
                result = NSDragOperationNone;
            
            if( dragging_over_dir ) {
                // check that we dont drag a folder into itself
                // filenames are stored without trailing slashes, so have to add it
                for(PanelDraggingItem *item: source.items)
                    if( item.item.Host() == destination.Host() &&
                        item.item.IsDir() &&
                        destination.Path() == item.item.Path()+"/" ) {
                        result = NSDragOperationNone;
                        break;
                    }
            }
        }
        else if( [_dragging.draggingPasteboard.types containsObject:url_uti] ) {
            // drag is from some other application
            valid_items = CountAcceptableDraggingItemsExt(_dragging,url_uti);
            NSDragOperation mask = _dragging.draggingSourceOperationMask;
            if( mask & NSDragOperationCopy )
                result = NSDragOperationCopy;
        }
        else if( [_dragging.draggingPasteboard.types containsObject:url_promise_uti]
                 && destination.Host()->IsNativeFS() ) {
            // tell we can accept file promises drags
            valid_items = CountAcceptableDraggingItemsExt(_dragging, url_promise_uti);
            NSDragOperation mask = _dragging.draggingSourceOperationMask;
            if( mask & NSDragOperationMove )
                result = NSDragOperationMove;
            else if( mask & NSDragOperationCopy )
                result = NSDragOperationCopy;
        }
    }
    
    
    if( valid_items == 0 ) {
        // regardless of a previous logic - we can't accept an unacceptable drags
        result = NSDragOperationNone;
    }
    else if( result == NSDragOperationNone ) {
        // inverse - we can't drag here anything - amount of draggable items should be zero
        valid_items = 0;
    }
    
    UpdateValidDropNumber( _dragging, valid_items, result );
    _dragging.draggingFormation = NSDraggingFormationList;
    
    return result;
}

- (bool) performDragOperation:(id<NSDraggingInfo>)_dragging
                 forPanelItem:(int)_sorted_index
{
    static const auto url_promise_uti = FilesDraggingSource.fileURLsPromiseDragUTI;
    static const auto url_uti = FilesDraggingSource.fileURLsDragUTI;

    const auto dragging_over_item = self.data.EntryAtSortPosition(_sorted_index);
    const auto destination = [self composeDestinationForDrag:_dragging
                                               overPanelItem:dragging_over_item];
    if( !destination )
        return false;

    const auto pasteboard = _dragging.draggingPasteboard;
    const auto dest_writeable = destination.Host()->IsWritable();
    const auto dest_native = destination.Host()->IsNativeFS();
    
    if( auto source = objc_cast<FilesDraggingSource>(_dragging.draggingSource) ) {
        
        if( !dest_writeable )
            return false;
        
        // we're dragging something here from another PanelView, lets understand what actually
        vector<VFSListingItem> files;
        for( PanelDraggingItem *item: source.items )
            files.emplace_back( item.item );
        if( files.empty() )
            return false;
        
        const auto operation = BuildOperationMaskForLocal(source, destination);
        
        if( operation == NSDragOperationCopy ) {
            FileCopyOperationOptions opts = MakeDefaultFileCopyOptions();
            auto op = [[FileCopyOperation alloc] initWithItems:move(files)
                                               destinationPath:destination.Path()
                                               destinationHost:destination.Host()
                                                       options:opts];
            __weak PanelController *dst_cntr = self;
            [op AddOnFinishHandler:^{
                dispatch_to_main_queue([dst_cntr]{
                    if(PanelController *pc = dst_cntr) [pc refreshPanel];
                });
            }];
            [self.state.OperationsController AddOperation:op];
            return true;
        }
        else if( operation == NSDragOperationMove ) {
            FileCopyOperationOptions opts = MakeDefaultFileMoveOptions();
            auto op = [[FileCopyOperation alloc] initWithItems:move(files)
                                               destinationPath:destination.Path()
                                               destinationHost:destination.Host()
                                                       options:opts];
            __weak PanelController *src_cntr = source.sourceController;
            __weak PanelController *dst_cntr = self;
            [op AddOnFinishHandler:^{
                dispatch_to_main_queue([src_cntr, dst_cntr]{
                    if(PanelController *pc = src_cntr) [pc refreshPanel];
                    if(PanelController *pc = dst_cntr) [pc refreshPanel];
                });
            }];
            [self.state.OperationsController AddOperation:op];
            return true;
        }
        else if( operation == NSDragOperationLink &&
                files.size() == 1 &&
                source.areAllHostsNative &&
                destination.Host()->IsNativeFS() ) {
            path source_path = files.front().Path();
            path dest_path = path(destination.Path()) / files.front().Filename();
            const auto op = make_shared<nc::ops::Linkage>(
                dest_path.native(), source_path.native(),
                destination.Host(), nc::ops::LinkageType::CreateSymlink);
            [self.mainWindowController enqueueOperation:op];
            return true;
        }
    }
    else if( [pasteboard.types containsObject:url_uti] && dest_writeable ) {
        static const auto read_opts = @{NSPasteboardURLReadingFileURLsOnlyKey:@YES};
        auto fileURLs = [pasteboard readObjectsForClasses:@[NSURL.class]
                                                  options:read_opts];
        
        // currently fetching listings synchronously, which is BAAAD
        auto source_items = FetchVFSListingsItemsFromDirectories(
            LayoutArraysOfURLsByDirectories(fileURLs),
            *VFSNativeHost::SharedHost());
        
        if( source_items.empty() )
            return false; // errors on fetching listings?
        
        // TODO: support move from other apps someday?
        FileCopyOperationOptions opts = MakeDefaultFileCopyOptions();
        auto op = [[FileCopyOperation alloc] initWithItems:move(source_items)
                                           destinationPath:destination.Path()
                                           destinationHost:destination.Host()
                                                   options:opts];
        
        __weak PanelController *dst_cntr = self;
        [op AddOnFinishHandler:^{
            dispatch_to_main_queue([dst_cntr]{
                if(PanelController *pc = dst_cntr) [pc refreshPanel];
            });
        }];
        [self.state.OperationsController AddOperation:op];
        return true;
    }
    else if( [pasteboard.types containsObject:url_promise_uti] && dest_native ) {
        // accept file promises drags
        const auto drop_url = [NSURL fileURLWithFileSystemRepresentation:destination.Path().c_str()
                                                             isDirectory:true
                                                           relativeToURL:nil];
        [_dragging namesOfPromisedFilesDroppedAtDestination:drop_url];
        return true;
    }
    
    return false;
}

@end
