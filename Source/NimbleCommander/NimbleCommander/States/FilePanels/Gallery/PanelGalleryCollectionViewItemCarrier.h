// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Panel/PanelDataItemVolatileData.h>
#include "Layout.h"

@class NCPanelGalleryCollectionViewItem;

// NCPanelGalleryCollectionViewItemCarrier class is responsible for the view elements corresponding to file items
// shown in the horizontal collection.
@interface NCPanelGalleryCollectionViewItemCarrier : NSView

@property(nonatomic, weak) NCPanelGalleryCollectionViewItem *controller;
@property(nonatomic) NSImage *icon;
@property(nonatomic) NSString *filename;
@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;
@property(nonatomic) NSColor *filenameColor;
@property(nonatomic) NSColor *backgroundColor;
@property(nonatomic) nc::panel::data::QuickSearchHiglight qsHighlight;

@end
