#pragma once

#include "PanelViewTypes.h"

class PanelData;
struct PanelDataSortMode;

@protocol PanelViewImplementationProtocol <NSObject>
@required

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic, readonly) int maxNumberOfVisibleItems;
@property (nonatomic) int cursorPosition;
@property (nonatomic) PanelDataSortMode sortMode;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;
- (bool) isItemVisible:(int)_sorted_item_index;

- (void) setupFieldEditor:(NSScrollView*)_editor forItemAtIndex:(int)_sorted_item_index;

- (void) onScrollToBeginning:(NSEvent*)_event;
- (void) onScrollToEnd:(NSEvent*)_event;
- (void) onPageUp:(NSEvent*)_event;
- (void) onPageDown:(NSEvent*)_event;

- (int) sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options;

@end


