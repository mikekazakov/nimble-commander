#pragma once

#include "PanelViewTypes.h"

namespace nc::panel::data {
    struct SortMode;
    class Model;
}

@protocol PanelViewImplementationProtocol <NSObject>
@required

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic, readonly) int maxNumberOfVisibleItems;
@property (nonatomic) int cursorPosition;
@property (nonatomic) nc::panel::data::SortMode sortMode;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(nc::panel::data::Model*)_data;
- (bool) isItemVisible:(int)_sorted_item_index;

- (void) setupFieldEditor:(NSScrollView*)_editor forItemAtIndex:(int)_sorted_item_index;

- (void) onScrollToBeginning:(NSEvent*)_event;
- (void) onScrollToEnd:(NSEvent*)_event;
- (void) onPageUp:(NSEvent*)_event;
- (void) onPageDown:(NSEvent*)_event;

- (int) sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options;

@end


