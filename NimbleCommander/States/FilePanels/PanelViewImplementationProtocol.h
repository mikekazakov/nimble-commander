#pragma once

class PanelData;
struct PanelDataSortMode;

@protocol PanelViewImplementationProtocol <NSObject>
@required

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) PanelDataSortMode sortMode;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;
- (bool) isItemVisible:(int)_sorted_item_index;

- (void) setupFieldEditor:(NSScrollView*)_editor forItemAtIndex:(int)_sorted_item_index;

@end


