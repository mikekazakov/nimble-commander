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

@end


