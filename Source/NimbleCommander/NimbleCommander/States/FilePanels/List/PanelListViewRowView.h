// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include <Panel/PanelDataItemVolatileData.h>

@class PanelListView;
@class PanelListViewNameView;
@class PanelListViewSizeView;

@interface PanelListViewRowView : NSTableRowView

- (id)initWithItem:(VFSListingItem)_item;

@property(nonatomic) VFSListingItem item; // may be empty!
@property(nonatomic) nc::panel::data::ItemVolatileData vd;
@property(nonatomic, weak) PanelListView *listView;
@property(nonatomic, readonly) NSColor *rowBackgroundColor;
@property(nonatomic, readonly) NSColor *rowTextColor;
@property(nonatomic, readonly) NSColor *tagAccentColor; // may return nil when no accent should be drawn
@property(nonatomic) bool panelActive;
@property(nonatomic) int itemIndex;
@property(nonatomic, readonly) PanelListViewNameView *nameView;
@property(nonatomic, readonly) PanelListViewSizeView *sizeView;

@end
