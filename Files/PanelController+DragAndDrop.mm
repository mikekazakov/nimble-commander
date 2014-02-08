//
//  PanelController+DragAndDrop.m
//  Files
//
//  Created by Michael G. Kazakov on 27.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+DragAndDrop.h"
#import "MainWindowFilePanelState.h"
#import "PanelDraggingItem.h"
#import "FileCopyOperation.h"
#import "FileLinkOperation.h"
#import "OperationsController.h"
#import "FontExtras.h"

static NSString *kPrivateDragUTI = @"info.filesmanager.filepanelsdraganddrop";

static NSFont *FontForDragImages()
{
    static dispatch_once_t once;
    static NSFont *font = nil;
    
    dispatch_once(&once, ^{
        font = [NSFont fontWithName:@"Lucida Grande" size:13];
    });

    return font;
}

static NSArray* BuildImageComponentsForItem(PanelDraggingItem* _item)
{
    if(_item == nil ||
       !_item.IsValid)
        return nil;
    
    NSDraggingImageComponent *imageComponent;
    NSMutableArray *components = [NSMutableArray arrayWithCapacity:2];
    
    NSFont *font = FontForDragImages();
    double font_ascent;
    double font_descent;
    double line_height = GetLineHeightForFont( (__bridge CTFontRef) font, &font_ascent, &font_descent);
    
    NSImage *icon_image;
    if(_item.VFS->IsNativeFS())
    {
        string path = _item.Path + _item.Filename;
        icon_image = [[NSWorkspace sharedWorkspace] iconForFile:[NSString stringWithUTF8String:path.c_str()]];
    }
    else
    {
        icon_image = [NSWorkspace.sharedWorkspace iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    }
    
    [icon_image setSize:NSMakeSize(line_height, line_height)];
    imageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
    imageComponent.frame = NSMakeRect(0, 0, line_height, line_height);
    imageComponent.contents = icon_image;
    [components addObject:imageComponent];
    
    
    double label_width = 250;
    
    NSImage *label_image = [[NSImage alloc] initWithSize:CGSizeMake(label_width, line_height)];
    [label_image lockFocus];
    
    
    NSShadow *label_shadow = [NSShadow new];
    label_shadow.shadowBlurRadius = 1;
    label_shadow.shadowColor = [NSColor colorWithDeviceRed:0.83 green:0.93 blue:1 alpha:1];
    label_shadow.shadowOffset = NSMakeSize(0, -1);
    
    NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new];
    item_text_pstyle.alignment = NSLeftTextAlignment;
    item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    NSDictionary *attributes = @{ NSFontAttributeName: font,
                                  NSForegroundColorAttributeName: [NSColor blackColor],
                                  NSParagraphStyleAttributeName: item_text_pstyle,
                                  NSShadowAttributeName: label_shadow };
    
    NSString *itemName = [NSString stringWithUTF8String:_item.Filename.c_str()];
    
    [itemName drawWithRect:NSMakeRect(0, font_descent, label_width, line_height)
                   options:0
                attributes:attributes];
    
    [label_image unlockFocus];
    imageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey];
    imageComponent.frame = NSMakeRect(line_height + 7, 0, label_width, line_height);
    imageComponent.contents = label_image;
    [components addObject:imageComponent];
    
    return components;
}


@interface PanelControllerDragSourceBroker : NSObject<NSDraggingSource, NSPasteboardItemDataProvider>
@property (weak) PanelController* controller;
@property shared_ptr<VFSHost> vfs;
@property string root_path;
@property int count;
@end

@implementation PanelControllerDragSourceBroker
{
    NSURL *m_URLPromiseTarget;
    shared_ptr<VFSHost> m_VFS;
    int m_Count;
}

@synthesize vfs = m_VFS;
@synthesize count = m_Count;

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch(context) {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationCopy;
            break;
            
        case NSDraggingContextWithinApplication:
            // need some complex logic here later
            
            if(m_Count > 1 || !m_VFS->IsNativeFS())
                return NSDragOperationCopy|NSDragOperationMove;
                
            return NSDragOperationCopy|NSDragOperationLink|NSDragOperationMove;
            
        default:
            return NSDragOperationNone;
    }
}


- (void)pasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item provideDataForType:(NSString *)type
{
    if ([type isEqualToString:(NSString *)kPasteboardTypeFileURLPromise])
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
        
        string dest = m_URLPromiseTarget.path.fileSystemRepresentation;
        if(dest.back() != '/')
            dest += '/';
        dest += item.Filename;
        
        VFSEasyCopyNode((item.Path+item.Filename).c_str(),
                        item.VFS,
                        dest.c_str(),
                        make_shared<VFSNativeHost>()
                        );

        [item setString:[NSString stringWithUTF8String:dest.c_str()]
                forType:(NSString *)kPasteboardTypeFileURLPromise];
    }
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    for(PanelDraggingItem *item in [session.draggingPasteboard readObjectsForClasses:@[[PanelDraggingItem class]]
                                                                             options:nil])
        [item Clear];
    
    m_VFS.reset();
}

@end



@implementation PanelController (DragAndDrop)

- (void) RegisterDragAndDropListeners
{
    [m_View registerForDraggedTypes:@[kPrivateDragUTI]];
}

- (void) PanelViewWantsDragAndDrop:(PanelView*)_view event:(NSEvent *)_event
{
    auto *focus_item = m_View.CurrentItem;
    if( focus_item == nullptr || focus_item->IsDotDot() == true )
        return;
    
    PanelControllerDragSourceBroker *broker = [PanelControllerDragSourceBroker new];
    broker.controller = self;
    broker.vfs = self.GetCurrentVFSHost;
    broker.root_path = m_Data.DirectoryPathWithTrailingSlash();
    
    NSMutableArray *drag_items = [NSMutableArray new];
    
    vector<const VFSListingItem*> vfs_items;
    
    if(focus_item->CFIsSelected() == false)
        vfs_items.push_back(focus_item);
    else
        for(auto &i: *m_Data.Listing())
            if(i.CFIsSelected())         // get all selected from listing
                vfs_items.push_back(&i);
    
    NSPoint dragPosition = [_view convertPoint:[_event locationInWindow] fromView:nil];
    dragPosition.x -= 16;
    dragPosition.y -= 16;
    
    for(auto *i: vfs_items) {
        PanelDraggingItem *pbItem = [PanelDraggingItem new];
        [pbItem setDataProvider:broker
                       forTypes:@[(NSString *)kPasteboardTypeFileURLPromise, kPrivateDragUTI]];
        
        [pbItem setString:(NSString*)kUTTypeData forType:(NSString *)kPasteboardTypeFilePromiseContent];
        [pbItem SetFilename:i->Name()];
        [pbItem SetPath:broker.root_path];
        [pbItem SetVFS:m_Data.Host()];
        
        
        NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
        dragItem.draggingFrame = NSMakeRect(dragPosition.x, dragPosition.y, 32, 32);

        __weak PanelDraggingItem *weak_drag_item = pbItem;
        dragItem.imageComponentsProvider = ^{
            return BuildImageComponentsForItem((PanelDraggingItem *)weak_drag_item);
        };
        
        [drag_items addObject:dragItem];
        dragPosition.y -= 16;
    }
    
    broker.count = drag_items.count;
    if(drag_items.count > 0)
        [_view beginDraggingSessionWithItems:drag_items event:_event source:broker];
}

- (NSDragOperation)PanelViewDraggingEntered:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    if(id idsource = sender.draggingSource)
        if([idsource isKindOfClass:[PanelControllerDragSourceBroker class]]) {
            PanelControllerDragSourceBroker *source = (PanelControllerDragSourceBroker *)idsource;
            if(source.controller == self) {
                return NSDragOperationNone;
            }
            else {
                // some logic regarding R/W situation on medium and link capabilities should be here
                NSDragOperation mask = sender.draggingSourceOperationMask;
                if(mask == (NSDragOperationCopy|NSDragOperationLink|NSDragOperationMove))
                    return NSDragOperationMove;
                if(mask == (NSDragOperationCopy|NSDragOperationMove))
                    return NSDragOperationMove;
                
                return mask;
            }
        }
    return NSDragOperationNone;
}

- (NSDragOperation)PanelViewDraggingUpdated:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    return [self PanelViewDraggingEntered:_view sender:sender];
}

- (BOOL) PanelViewPerformDragOperation:(PanelView*)_view sender:(id <NSDraggingInfo>)sender
{
    if(id idsource = sender.draggingSource)
        if([idsource isKindOfClass:[PanelControllerDragSourceBroker class]]) {
            // we're dragging something here from another PanelView, lets understand what actually
            PanelControllerDragSourceBroker *source_broker = (PanelControllerDragSourceBroker *)idsource;
            PanelController *source_controller = source_broker.controller;
            MainWindowFilePanelState* filepanel_state = self.state;
            assert(source_controller != self);
            
            // currently we accept only copying to native fs
            if(!m_HostsStack.back()->IsNativeFS())
                return false;
            
            chained_strings files;
            for(PanelDraggingItem *item in [sender.draggingPasteboard readObjectsForClasses:@[[PanelDraggingItem class]]
                                                                                    options:nil])
                files.push_back(item.Filename, nullptr);

            if(files.empty())
                return false;
            
            if(sender.draggingSourceOperationMask == NSDragOperationCopy) {
                string destination = self.GetCurrentDirectoryPathRelativeToHost;
                FileCopyOperationOptions opts;
                FileCopyOperation *op = [[FileCopyOperation alloc] initWithFiles:move(files)
                                                                            root:source_broker.root_path.c_str()
                                                                         rootvfs:source_broker.vfs
                                                                            dest:destination.c_str()
                                                                         options:&opts];
                    
                [filepanel_state.OperationsController AddOperation:op];
                return true;
            }
            if(sender.draggingSourceOperationMask == NSDragOperationMove ||
               sender.draggingSourceOperationMask == (NSDragOperationMove|NSDragOperationLink) ||
               sender.draggingSourceOperationMask == (NSDragOperationMove|NSDragOperationCopy|NSDragOperationLink)) {
                string destination = self.GetCurrentDirectoryPathRelativeToHost;
                FileCopyOperationOptions opts;
                opts.docopy = false;
                FileCopyOperation *op;
                if(source_broker.vfs->IsNativeFS()) // we'll use straight native->native copy
                    op = [[FileCopyOperation alloc] initWithFiles:move(files)
                                                             root:source_broker.root_path.c_str()
                                                             dest:destination.c_str()
                                                          options:&opts];
                else // here we'll use vfs->native copy (no removing actually - not yet implemented)
                    op = [[FileCopyOperation alloc] initWithFiles:move(files)
                                                             root:source_broker.root_path.c_str()
                                                          rootvfs:source_broker.vfs
                                                             dest:destination.c_str()
                                                          options:&opts];
                
                [filepanel_state.OperationsController AddOperation:op];
                return true;
            }
            if(sender.draggingSourceOperationMask == NSDragOperationLink &&
               files.size() == 1 &&
               source_broker.vfs->IsNativeFS() ) {
                string source_path = source_broker.root_path + files.front().c_str();
                string dest_path = self.GetCurrentDirectoryPathRelativeToHost + files.front().c_str();
                [filepanel_state.OperationsController AddOperation:
                    [[FileLinkOperation alloc] initWithNewSymbolinkLink:source_path.c_str()
                                                               linkname:dest_path.c_str()]];
                return true;
            }
        }
    
    
    
    return false;
}


@end
