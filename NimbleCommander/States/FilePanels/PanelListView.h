#pragma once

class PanelData;
struct PanelViewPresentationItemsColoringRule;
@class PanelView;


@interface PanelListView: NSView<NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules;

@end
