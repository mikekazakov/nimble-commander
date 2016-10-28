#pragma once

#include "../../../Files/PanelData.h"

@class PanelListView;
@class PanelListViewNameView;

@interface PanelListViewRowView : NSTableRowView

- (id) initWithItem:(VFSListingItem)_item atIndex:(int)index;

@property (nonatomic, readonly) VFSListingItem item;
@property (nonatomic) PanelData::PanelVolatileData vd;
@property (nonatomic, weak) PanelListView *listView;
@property (nonatomic, readonly) NSColor *rowBackgroundColor;
@property (nonatomic, readonly) NSColor *rowTextColor;
@property (nonatomic) bool panelActive;
@property (nonatomic, readonly) int itemIndex;
@property (nonatomic, readonly) PanelListViewNameView *nameView;

@end
