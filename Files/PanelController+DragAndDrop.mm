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
#import "OperationsController.h"
#import "FontExtras.h"




@interface PanelControllerDragSourceBroker : NSObject<NSDraggingSource, NSPasteboardItemDataProvider>
@property (weak) PanelController* controller;
@end

@implementation PanelControllerDragSourceBroker
{
    NSURL *m_URLPromiseTarget;
    
    
}

@synthesize controller;

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    return NSDragOperationCopy;
}


- (void)pasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item provideDataForType:(NSString *)type
{
    //    NSLog(@"%s", item.Path.c_str());
    //    NSLog(@"%@", sender.name);
//    NSLog(@"pasteboard:(NSPasteboard *)sender item:(PanelDraggingItem *)item provideDataForType:(NSString *)type");

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
                else
                    NSLog(@"failed to get url target");
                
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

//        [item setString:[NSString stringWithUTF8String:item.Filename.c_str()]
        [item setString:[NSString stringWithUTF8String:dest.c_str()]
                forType:(NSString *)kPasteboardTypeFileURLPromise];
    }
}

- (void)draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint
{
    //    NSLog(@"draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint");
}

- (void)draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint
{
    //    NSLog(@"draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint");
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
//    kPasteboardTypeFilePromiseContent
    
    return;
    if(operation == NSDragOperationCopy && m_URLPromiseTarget != nil)
    {
        chained_strings files;
        
        PanelDraggingItem *last;
        
        for(PanelDraggingItem *item in [session.draggingPasteboard readObjectsForClasses:@[[PanelDraggingItem class]]
                                                                   options:nil])
        {
            files.push_back(item.Filename, nullptr);
            last = item;
        }

        if(last)
        {
            string dest = m_URLPromiseTarget.path.fileSystemRepresentation;
            if(dest.back() != '/')
                dest += '/';
            
            FileCopyOperationOptions opts;
            FileCopyOperation *op = [[FileCopyOperation alloc] initWithFiles:move(files)
                                                                        root:last.Path.c_str()
                                                                     rootvfs:last.VFS
                                                                        dest:dest.c_str()
                                                                     options:&opts];
            
            PanelController *cont = (PanelController *)self.controller;
            [((MainWindowFilePanelState*)cont.state).OperationsController AddOperation:op];
        }
    }
    
    
    
    
//    NSLog(@"draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation");
    //    NSPasteboard *pb = session.draggingPasteboard;
    //    NSArray *items = pb.pasteboardItems;
    // clear items here
    
    //    [pb clearContents];
    //    [session.draggingPasteboard clearContents];
    //    int a = 10;
}

- (NSArray*) BuildImageComponentsForItem:(PanelDraggingItem*)_item
{
    if(_item == nil ||
       !_item.IsValid)
        return nil;
    
    NSDraggingImageComponent *imageComponent;
    NSMutableArray *components = [NSMutableArray arrayWithCapacity:2];

    NSFont *font = [NSFont fontWithName:@"Lucida Grande" size:13];
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

@end



@implementation PanelController (DragAndDrop)

- (void) PanelViewWantsDragAndDrop:(PanelView*)_view event:(NSEvent *)_event
{
    auto *focus_item = m_View.CurrentItem;
    if( focus_item == nullptr || focus_item->IsDotDot() == true )
        return;
    
    PanelControllerDragSourceBroker *broker = [PanelControllerDragSourceBroker new];
    broker.controller = self;
    
    NSMutableArray *drag_items = [NSMutableArray new];
    
    vector<const VFSListingItem*> vfs_items;
    
    if(focus_item->CFIsSelected() == false)
        vfs_items.push_back(focus_item);
    else
        for(auto &i: *m_Data.Listing())
            if(i.CFIsSelected())         // get all selected from listing
                vfs_items.push_back(&i);
    
//    if( item != nullptr &&
//       item->IsDotDot() == false )
    int ind = 0;
    for(auto *i: vfs_items)
    {
        PanelDraggingItem *pbItem = [PanelDraggingItem new];
        [pbItem setDataProvider:broker
                       forTypes:@[(NSString *)kPasteboardTypeFileURLPromise]];
        
//        kUTTypePNG
        
        [pbItem setString:/*@"*"*/(NSString*)kUTTypeData forType:(NSString *)kPasteboardTypeFilePromiseContent];
        [pbItem SetFilename:i->Name()];
        [pbItem SetPath:m_Data.DirectoryPathWithTrailingSlash()];
        [pbItem SetVFS:m_Data.Host()];
        
        NSPoint dragPosition = [_view convertPoint:[_event locationInWindow] fromView:nil];
        dragPosition.x -= 16;
        dragPosition.y -= 16*ind;
        
        NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
        dragItem.draggingFrame = NSMakeRect(dragPosition.x, dragPosition.y, 32, 32);

        __weak PanelDraggingItem *weak_drag_item = pbItem;
        dragItem.imageComponentsProvider = ^{
            return [broker BuildImageComponentsForItem:(PanelDraggingItem *)weak_drag_item];
        };
        
        [drag_items addObject:dragItem];
        
        ind++;
    }
    
    if(drag_items.count > 0)
    {
        NSDraggingSession *session = [_view beginDraggingSessionWithItems:drag_items
                                                                    event:_event
                                                                   source:broker];
    }
}


@end
