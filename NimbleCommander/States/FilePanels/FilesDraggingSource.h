// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
@class PanelController;

@interface PanelDraggingItem : NSPasteboardItem

@property (nonatomic, readonly) const VFSListingItem& item;
@property (nonatomic) NSImage                        *icon;

- (PanelDraggingItem*) initWithItem:(const VFSListingItem&)_item;
- (void) reset;

@end

@interface FilesDraggingSource : NSObject<NSDraggingSource, NSPasteboardItemDataProvider>

+ (NSString*) privateDragUTI;
+ (NSString*) fileURLsPromiseDragUTI;
+ (NSString*) fileURLsDragUTI;
+ (NSString*) filenamesPBoardDragUTI;

@property(nonatomic, readonly, weak) PanelController               *sourceController;
@property(nonatomic, readonly)  bool                                areAllHostsWriteable;
@property(nonatomic, readonly)  bool                                areAllHostsNative;
@property(nonatomic, readonly)  const VFSHostPtr&                   commonHost;
@property(nonatomic, readonly)  const vector<PanelDraggingItem*>&   items;

- (FilesDraggingSource*) initWithSourceController:(PanelController*)_controller;
- (void)writeURLsPBoard:(NSPasteboard*)_sender;
- (void)addItem:(PanelDraggingItem*)_item;

@end

