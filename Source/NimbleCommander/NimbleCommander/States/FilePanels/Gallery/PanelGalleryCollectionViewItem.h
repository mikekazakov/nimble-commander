// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include <Panel/PanelDataItemVolatileData.h>
#include "Layout.h"

@class PanelGalleryView;
@class NCPanelViewFieldEditor;

@interface NCPanelGalleryCollectionViewItem : NSCollectionViewItem

@property(nonatomic) VFSListingItem item;

// Index of this item within the collection view, i.e. its sorted index.
// -1 denotes invalid index.
@property(nonatomic, readonly) int itemIndex;

@property(nonatomic) nc::panel::data::ItemVolatileData vd;

@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;

@property(nonatomic) bool panelActive;

@property(nonatomic) NSImage *icon;

@property(nonatomic, readonly) PanelGalleryView *galleryView;

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor;

@end
