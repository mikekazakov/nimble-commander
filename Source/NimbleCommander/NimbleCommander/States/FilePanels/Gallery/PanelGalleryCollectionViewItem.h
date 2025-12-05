// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include <Panel/PanelDataItemVolatileData.h>
#include "Layout.h"

@interface NCPanelGalleryCollectionViewItem : NSCollectionViewItem

@property(nonatomic) VFSListingItem item;

@property(nonatomic) nc::panel::data::ItemVolatileData vd;

@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;

@property(nonatomic) bool panelActive;

@property(nonatomic) NSImage *icon;

@end
