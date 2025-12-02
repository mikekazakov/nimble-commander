// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include "Layout.h"

@interface NCPanelGalleryCollectionViewItem : NSCollectionViewItem

@property(nonatomic) VFSListingItem item;

@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;

@property(nonatomic) NSImage *icon;

@end
