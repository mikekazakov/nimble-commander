#pragma once

class PanelData;

@protocol PanelViewImplementationProtocol <NSObject>
@required

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

@end


