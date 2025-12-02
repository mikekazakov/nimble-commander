// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

#include "Layout.h"

@class NCPanelGalleryCollectionViewItem;

@interface NCPanelGalleryCollectionViewItemCarrier : NSView

@property(nonatomic, weak) NCPanelGalleryCollectionViewItem *controller;
@property(nonatomic) NSImage *icon;
@property(nonatomic) NSString *filename;
@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;

//
//@property(nonatomic) NSColor *backgroundColor;
//@property(nonatomic) NSColor *tagAccentColor;
//@property(nonatomic) NSString *filename;
//@property(nonatomic) NSColor *filenameColor;

@end
