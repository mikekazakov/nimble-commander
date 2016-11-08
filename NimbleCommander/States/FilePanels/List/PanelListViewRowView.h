#pragma once

#include "../../../Files/OrthodoxMonospace.h"
#include "../../../Files/PanelData.h"

@class PanelListView;
@class PanelListViewNameView;

@interface PanelListViewRowView : NSTableRowView

- (id) initWithItem:(VFSListingItem)_item;

@property (nonatomic) VFSListingItem item; // may be empty!
@property (nonatomic) PanelData::PanelVolatileData vd;
@property (nonatomic, weak) PanelListView *listView;
@property (nonatomic, readonly) NSColor *rowBackgroundColor;
@property (nonatomic, readonly) DoubleColor rowBackgroundDoubleColor;
@property (nonatomic, readonly) NSColor *rowTextColor;
@property (nonatomic, readonly) DoubleColor rowTextDoubleColor;
@property (nonatomic) bool panelActive;
@property (nonatomic) int itemIndex;
@property (nonatomic, readonly) PanelListViewNameView *nameView;
//@property (nonatomic, readonly) NSDictionary *dateTimeViewTextAttributes;

@end
