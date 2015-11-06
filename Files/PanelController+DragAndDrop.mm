//
//  PanelController+DragAndDrop.m
//  Files
//
//  Created by Michael G. Kazakov on 27.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/FontExtras.h>
#include "vfs/vfs_native.h"
#include "PanelController+DragAndDrop.h"
#include "MainWindowFilePanelState.h"
#include "Operations/Copy/FileCopyOperation.h"
#include "FileLinkOperation.h"
#include "OperationsController.h"
#include "path_manip.h"
#include "Common.h"

static NSString *g_PrivateDragUTI = @__FILES_IDENTIFIER__".filepanelsdraganddrop";
static NSString *g_PasteboardFileURLPromiseUTI = (NSString *)kPasteboardTypeFileURLPromise;
static NSString *g_PasteboardFileURLUTI = (NSString *)kUTTypeFileURL;
static NSString *g_PasteboardFilenamesUTI = (NSString*)CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType, (__bridge CFStringRef)NSFilenamesPboardType, kUTTypeData));

// item holds a link to listing
// listing holds a link to vfs
@interface PanelDraggingItem : NSPasteboardItem
- (const VFSListingItem&) item;
- (void) setItem:(const VFSListingItem&)_item;
- (bool) IsValid;
- (void) Clear;
@end

static bool DraggingIntoFoldersAllowed()
{
    return [NSUserDefaults.standardUserDefaults boolForKey:@"FilePanelsGeneralAllowDraggingIntoFolders"];
}

static NSArray* BuildImageComponentsForItem(PanelDraggingItem* _item)
{
    if(_item == nil ||
       !_item.IsValid)
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

@implementation PanelDraggingItem
{
    VFSListingItem m_Item;
}

- (const VFSListingItem&) item
{
    return m_Item;
}

- (void) setItem:(const VFSListingItem&)_item
{
    m_Item = _item;
}

- (bool) IsValid
{
    return bool(m_Item);
}

- (void) Clear
{
    m_Item = VFSListingItem();
}

@end



@interface PanelControllerDragSourceBroker : NSObject<NSDraggingSource, NSPasteboardItemDataProvider>
@property(weak)         PanelController    *controller;
@property(nonatomic)    bool                areAllHostsWriteable;
@property(nonatomic)    bool                areAllHostsNative;
@property(readonly, nonatomic)    unsigned            count;
@property(nonatomic)    vector<PanelDraggingItem*>& items;
@end

@implementation PanelControllerDragSourceBroker
{
    NSURL                       *m_URLPromiseTarget;
    vector<PanelDraggingItem*>  m_Items;
    optional<bool>              m_AreAllHostsWriteable;
    optional<bool>              m_AreAllHostsNative;
    bool                        m_FilenamesPasteboardDone;
    bool                        m_FilenamesPasteboardEnabled;
}

@synthesize count = m_Count;
@synthesize items = m_Items;

- (id)init
{
    self = [super init];
    if(self) {
        m_FilenamesPasteboardDone = false;
        m_FilenamesPasteboardEnabled = true;
    }
    return self;
}

- (unsigned) count
{
    return (unsigned)m_Items.size();
}

- (bool) areAllHostsWriteable
{
    if(m_AreAllHostsWriteable)
        return *m_AreAllHostsWriteable;
    m_AreAllHostsWriteable = true;
    for(auto i: m_Items)
        if( !i.item.Host()->IsWriteable() ) {
            m_AreAllHostsWriteable = false;
            break;
        }
    return *m_AreAllHostsWriteable;
}

- (bool) areAllHostsNative
{
    if(m_AreAllHostsNative)
        return *m_AreAllHostsNative;
    m_AreAllHostsNative = true;
    for(auto i: m_Items)
        if( !i.item.Host()->IsNativeFS() ) {
            m_AreAllHostsNative = false;
            break;
        }
    return *m_AreAllHostsNative;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch(context) {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationCopy;
            break;
            
        case NSDraggingContextWithinApplication:
            // need some complex logic here later
            
            if( m_Count > 1 || !self.areAllHostsNative )
                return NSDragOperationCopy|NSDragOperationMove;
            
            return NSDragOperationCopy|NSDragOperationLink|NSDragOperationMove;
            
        default:
            return NSDragOperationNone;
    }
}


- (void)pasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item provideDataForType:(NSString *)type
{
    // OldStyleDone means that we already pushed the whole files list at once
    // in this case any other items should be simply ignored
    if(m_FilenamesPasteboardDone)
        return;
    
    if(m_FilenamesPasteboardEnabled && [type isEqualToString:g_PasteboardFilenamesUTI])
    { // old style is turned on by some special conditions
        NSMutableArray *ar = [NSMutableArray new];
        for(auto &i: m_Items)
            [ar addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8StdString:i.item.Path()]]];
        [sender writeObjects:ar];
        m_FilenamesPasteboardDone = true;
    }
    else if ([type isEqualToString:g_PasteboardFileURLPromiseUTI])
    {
        if(m_URLPromiseTarget == nil)
        {
            PasteboardRef pboardRef = NULL;
            PasteboardCreate((__bridge CFStringRef)sender.name, &pboardRef);
            if (pboardRef != NULL) {
                PasteboardSynchronize(pboardRef);
                CFURLRef urlRef = NULL;
                PasteboardCopyPasteLocation(pboardRef, &urlRef);
                if(urlRef)
                    m_URLPromiseTarget = (NSURL*) CFBridgingRelease(urlRef);
                
                CFRelease(pboardRef);
            }
        }

        if(m_URLPromiseTarget == nil)
            return;
        
        path dest = path(m_URLPromiseTarget.path.fileSystemRepresentation) / item.item.Filename();
        VFSEasyCopyNode(item.item.Path().c_str(), item.item.Host(),
                        dest.c_str(), VFSNativeHost::SharedHost());

        [item setString:[NSString stringWithUTF8String:dest.c_str()]
                forType:type];
        m_FilenamesPasteboardEnabled = false;
    }
    else if([type isEqualToString:g_PasteboardFileURLUTI])
    {
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:item.item.Path()]];
        [url writeToPasteboard:sender];
        m_FilenamesPasteboardEnabled = false;
    }
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    for(PanelDraggingItem *item in [session.draggingPasteboard readObjectsForClasses:@[PanelDraggingItem.class]
                                                                             options:nil])
        if(item.class == PanelDraggingItem.class) // wtf????
            [item Clear];
    m_URLPromiseTarget = nil;
    m_Items.clear();
}

@end



@implementation PanelController (DragAndDrop)

+ (NSString*) dragAndDropPrivateUTI
{
    return g_PrivateDragUTI;
}

- (void) RegisterDragAndDropListeners
{
    [m_View registerForDraggedTypes:@[g_PrivateDragUTI, g_PasteboardFileURLUTI, g_PasteboardFileURLPromiseUTI]];
}

- (void) PanelViewWantsDragAndDrop:(PanelView*)_view event:(NSEvent *)_event
{
    auto focus_item = m_View.item;
    if( !focus_item || focus_item.IsDotDot() )
        return;
    
    PanelControllerDragSourceBroker *broker = [PanelControllerDragSourceBroker new];
    broker.controller = self;
    
    NSMutableArray *drag_items = [NSMutableArray new];
    
    vector<VFSListingItem> vfs_items;
    
    if( m_View.item_vd.is_selected() == false)
        vfs_items.emplace_back(focus_item);
    else
        vfs_items = m_Data.SelectedEntries();
    
    NSPoint dragPosition = [_view convertPoint:_event.locationInWindow fromView:nil];
    dragPosition.x -= 16;
    dragPosition.y -= 16;
    
    NSMutableArray *pasteboard_types = [NSMutableArray new];
    [pasteboard_types addObject:g_PasteboardFileURLPromiseUTI];
    [pasteboard_types addObject:g_PrivateDragUTI];
    if( self.isUniform && self.vfs->IsNativeFS() ) {
        [pasteboard_types addObject:g_PasteboardFilenamesUTI];
        [pasteboard_types addObject:g_PasteboardFileURLUTI];
    }
    
    for(auto &i: vfs_items) {
        PanelDraggingItem *pbItem = [PanelDraggingItem new];
        [pbItem setDataProvider:broker forTypes:pasteboard_types];
    
        // internal information
        pbItem.item = i;

        // for File URL Promise
        [pbItem setString:(NSString*)kUTTypeData forType:(NSString *)kPasteboardTypeFilePromiseContent];
        
        // visual appearance of a drag
        NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
        dragItem.draggingFrame = NSMakeRect(dragPosition.x, dragPosition.y, 32, 32);

        __weak PanelDraggingItem *weak_drag_item = pbItem;
        dragItem.imageComponentsProvider = ^{
            return BuildImageComponentsForItem((PanelDraggingItem *)weak_drag_item);
        };
        
        [drag_items addObject:dragItem];
        dragPosition.y -= 16;
        
        broker.items.push_back(pbItem);
    }
    
    if(drag_items.count > 0)
        [_view beginDraggingSessionWithItems:drag_items event:_event source:broker];
}

- (int) countAcceptableDraggingItemsExt:(id <NSDraggingInfo>)sender forType:(NSString *)type
{
    __block int urls_amount = 0;
    [sender enumerateDraggingItemsWithOptions:NSDraggingItemEnumerationClearNonenumeratedImages
                                      forView:self.view
                                      classes:@[NSPasteboardItem.class]
                                searchOptions:@{}
                                   usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
                                       if( [((NSPasteboardItem*)draggingItem.item).types containsObject:type] )
                                           urls_amount++;
                                   }];
    return urls_amount;
}

#if 0
- (path) __composeDestinationForDragOld:(id <NSDraggingInfo>)sender
{
    int dragging_over_item_no = [m_View sortedItemPosAtPoint:[m_View convertPoint:sender.draggingLocation fromView:nil]
                                               hitTestOption:PanelViewHitTest::FilenameFact];
    auto dragging_over_item = m_Data.EntryAtSortPosition(dragging_over_item_no);
    bool dragging_over_dir = dragging_over_item && dragging_over_item.IsDir() && DraggingIntoFoldersAllowed();
    path destination_dir = self.currentDirectoryPath;
    destination_dir.remove_filename();
    if(destination_dir.empty())
        destination_dir = "/";
    if(dragging_over_dir) { // alter destination regarding to where drag is currently placed
        if(!dragging_over_item.IsDotDot())
            destination_dir /= dragging_over_item.Name();
        else
            destination_dir = destination_dir.parent_path();
    }
    destination_dir /= "/";
    return destination_dir;
}
#endif

// may return {nullptr, ""} if dragging into non-uniform listing
- (VFSPath) composeDestinationForDrag:(id <NSDraggingInfo>)sender
{
    const auto dragging_mouse_pos = [m_View convertPoint:sender.draggingLocation fromView:nil];
    const int dragging_over_item_no = [m_View sortedItemPosAtPoint:dragging_mouse_pos hitTestOption:PanelViewHitTest::FilenameFact];
    
    
    const auto dragging_over_item = m_Data.EntryAtSortPosition(dragging_over_item_no);
    const bool dragging_over_dir = dragging_over_item &&
                                    dragging_over_item.IsDir() &&
                                    DraggingIntoFoldersAllowed();
    
    if( dragging_over_dir ) {
        if( dragging_over_item.IsDotDot() ) {
            if( !self.isUniform )
                return {};
            path p = self.currentDirectoryPath;
            p.remove_filename();
            if(p.empty())
                p = "/";
            return {self.vfs, (p.parent_path() / "/").native()};
        }
        else {
            auto p = path(dragging_over_item.Directory()) / dragging_over_item.Filename() / "/";
            return {dragging_over_item.Host(), p.native()};
        }
    }
    else {
        if( !self.isUniform )
            return {};
        return {self.vfs, self.currentDirectoryPath};
    }
}

- (NSDragOperation)PanelViewDraggingEntered:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    int valid_items = 0;
    int dragging_over_item_no = [m_View sortedItemPosAtPoint:[m_View convertPoint:sender.draggingLocation fromView:nil]
                                            hitTestOption:PanelViewHitTest::FilenameFact];
    auto dragging_over_item = m_Data.EntryAtSortPosition(dragging_over_item_no);
    bool dragging_over_dir = dragging_over_item && dragging_over_item.IsDir() && DraggingIntoFoldersAllowed();
    auto destination = [self composeDestinationForDrag:sender];
    
    
    NSDragOperation result = NSDragOperationNone;
    if( destination && destination.Host()->IsWriteable()) {
        if( auto source = objc_cast<PanelControllerDragSourceBroker>(sender.draggingSource) ) {
            // drag is from some other panel
            valid_items = (int)source.items.size();
            if(source.controller == self && !dragging_over_dir) {
                result = NSDragOperationNone; // we can't drag into the same dir on the same panel
            }
            else {
                NSDragOperation mask = sender.draggingSourceOperationMask;
                if( mask == (NSDragOperationMove|NSDragOperationCopy|NSDragOperationLink) ||
                    mask == (NSDragOperationMove|NSDragOperationLink) ||
                    mask == (NSDragOperationMove|NSDragOperationCopy) )
                    result = source.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
                else
                    result = mask;
            }

            // check that we dont drag an item to the same folder in other panel
            if( any_of(begin(source.items), end(source.items), [&](auto &_i) {
                return _i.item.Directory() == destination.Path() && _i.item.Host() == destination.Host(); }) )
                result = NSDragOperationNone;
            
            // TODO: why do we use sender.draggingPasteboard here insead of source.items?
            // check that we dont drag a folder into itself
            if( dragging_over_dir )
                for(PanelDraggingItem *item in [sender.draggingPasteboard readObjectsForClasses:@[PanelDraggingItem.class]
                                                                                        options:nil])
                    if( item.item.Host() == destination.Host() &&
                        item.item.IsDir() &&
                        destination.Path() == item.item.Path()+"/" ) { // filenames are stored without trailing slashes, so have to add it
                        result = NSDragOperationNone;
                        break;
                    }
        }
        else if([sender.draggingPasteboard.types containsObject:g_PasteboardFileURLUTI]) {
            // drag is from some other application
            valid_items = [self countAcceptableDraggingItemsExt:sender forType:g_PasteboardFileURLUTI];
            NSDragOperation mask = sender.draggingSourceOperationMask;
            if(mask & NSDragOperationCopy)
                result = NSDragOperationCopy;
        }
        else if([sender.draggingPasteboard.types containsObject:g_PasteboardFileURLPromiseUTI] && destination.Host()->IsNativeFS() ) {
            // tell we can accept file promises drags
            valid_items = [self countAcceptableDraggingItemsExt:sender forType:g_PasteboardFileURLPromiseUTI];
            NSDragOperation mask = sender.draggingSourceOperationMask;
            if( mask & NSDragOperationMove )
                result = NSDragOperationMove;
            else if( mask & NSDragOperationCopy )
                result = NSDragOperationCopy;
        }
    }
    
    if(valid_items == 0) // regardless of a previous logic - we can't accept an unacceptable drags
        result = NSDragOperationNone;
    else if(result == NSDragOperationNone) // inverse - we can't drag here anything - amount of draggable items is zero
        valid_items = 0;
    
    if(valid_items != m_DragDrop.last_valid_items) {
        m_DragDrop.last_valid_items = valid_items;
        sender.numberOfValidItemsForDrop = valid_items;
    }
    
    if(result != NSDragOperationNone) {
        m_View.draggingOver = true;
        m_View.draggingOverItemAtPosition = dragging_over_dir ? dragging_over_item_no : -1;
    }
    else {
        m_View.draggingOver = false;
        m_View.draggingOverItemAtPosition = -1;
    }
    
    sender.draggingFormation = NSDraggingFormationList;
    
    return result;
}

- (NSDragOperation)PanelViewDraggingUpdated:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    return [self PanelViewDraggingEntered:_view sender:sender];
}

- (void)PanelViewDraggingExited:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    m_DragDrop.last_valid_items = -1;
    m_View.draggingOver = false;
    m_View.draggingOverItemAtPosition = -1;
}

- (BOOL) PanelViewPerformDragOperation:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    // clear UI from dropping information
    m_DragDrop.last_valid_items = -1;
    m_View.draggingOver = false;
    m_View.draggingOverItemAtPosition = -1;
    
    auto destination = [self composeDestinationForDrag:sender];
    if( !destination )
        return false;
    
    if( auto source_broker = objc_cast<PanelControllerDragSourceBroker>(sender.draggingSource) ) {
        // we're dragging something here from another PanelView, lets understand what actually
        auto opmask = sender.draggingSourceOperationMask;
        
        vector<VFSListingItem> files;
        for(PanelDraggingItem *item in [sender.draggingPasteboard readObjectsForClasses:@[PanelDraggingItem.class]
                                                                                options:nil])
            files.emplace_back( item.item );
        
        if( files.empty() )
            return false;
        
        if( !destination.Host()->IsWriteable()  )
            return false;
        
        if( opmask == (NSDragOperationMove|NSDragOperationCopy|NSDragOperationLink) ||
            opmask == (NSDragOperationMove|NSDragOperationLink) ||
            opmask == (NSDragOperationMove|NSDragOperationCopy) )
            opmask = source_broker.areAllHostsWriteable ? NSDragOperationMove : NSDragOperationCopy;
        
        if( opmask == NSDragOperationCopy ) {
            FileCopyOperationOptions opts;
            auto op = [[FileCopyOperation alloc] initWithItems:move(files)
                                               destinationPath:destination.Path()
                                               destinationHost:destination.Host()
                                                       options:opts];
            __weak PanelController *dst_cntr = self;
            [op AddOnFinishHandler:^{
                dispatch_to_main_queue([dst_cntr]{
                    if(PanelController *pc = dst_cntr) [pc RefreshDirectory];
                });
            }];
            [self.state.OperationsController AddOperation:op];
            return true;
        }
        else if( opmask == NSDragOperationMove ) {
            FileCopyOperationOptions opts;
            opts.docopy = false;
            auto op = [[FileCopyOperation alloc] initWithItems:move(files)
                                               destinationPath:destination.Path()
                                               destinationHost:destination.Host()
                                                       options:opts];
            __weak PanelController *src_cntr = source_broker.controller;
            __weak PanelController *dst_cntr = self;
            [op AddOnFinishHandler:^{
                dispatch_to_main_queue([src_cntr, dst_cntr]{
                    if(PanelController *pc = src_cntr) [pc RefreshDirectory];
                    if(PanelController *pc = dst_cntr) [pc RefreshDirectory];
                });
            }];
            [self.state.OperationsController AddOperation:op];
            return true;
        }
        else if( opmask == NSDragOperationLink &&
                 files.size() == 1 &&
                 source_broker.areAllHostsNative &&
                 destination.Host()->IsNativeFS() ) {
            path source_path = files.front().Path();
            path dest_path = path(destination.Path()) / files.front().Filename();
            auto op = [[FileLinkOperation alloc] initWithNewSymbolinkLink:source_path.c_str()
                                                                 linkname:dest_path.c_str()];
            [self.state.OperationsController AddOperation:op];
            return true;
        }
    }
    else if( [sender.draggingPasteboard.types containsObject:g_PasteboardFileURLUTI] && destination.Host()->IsWriteable() ) {
        auto fileURLs = [sender.draggingPasteboard
                         readObjectsForClasses:@[NSURL.class]
                         options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES}
                         ];

        // currently fetching listings synchronously, which is BAAAD
        auto source_items = FetchVFSListingsItemsFromDirectories(LayoutArraysOfURLsByDirectories(fileURLs),
                                                                 *VFSNativeHost::SharedHost());
  
        if( source_items.empty() )
            return false; // errors on fetching listings?
        
        FileCopyOperationOptions opts;
        opts.docopy = true; // TODO: support move from other apps someday?
        auto op = [[FileCopyOperation alloc] initWithItems:move(source_items)
                                           destinationPath:destination.Path()
                                           destinationHost:destination.Host()
                                                   options:opts];
        
        __weak PanelController *dst_cntr = self;
        [op AddOnFinishHandler:^{
            dispatch_to_main_queue([dst_cntr]{
                if(PanelController *pc = dst_cntr) [pc RefreshDirectory];
            });
        }];
        [self.state.OperationsController AddOperation:op];
        return true;
    }
    else if( [sender.draggingPasteboard.types containsObject:g_PasteboardFileURLPromiseUTI] && destination.Host()->IsNativeFS() ) {
        // accept file promises drags
        NSURL *drop_url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:destination.Path()]];
        [sender namesOfPromisedFilesDroppedAtDestination:drop_url];
        return true;
    }
    
    return false;
}


@end
