#pragma once

class PanelData;
struct PanelViewPresentationItemsColoringRule;
@class PanelView;
class PanelListViewGeometry;

@interface PanelListView: NSView<NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

- (const vector<PanelViewPresentationItemsColoringRule>&) coloringRules;

- (const PanelListViewGeometry&) geometry;

- (NSFont*) font;

@end
