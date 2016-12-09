#pragma once

#include "PanelDataSortMode.h"
#include "List/Layout.h"
#include "PanelViewImplementationProtocol.h"

class PanelData;
struct PanelViewPresentationItemsColoringRule;
@class PanelView;
class PanelListViewGeometry;
class IconsGenerator2;

@interface PanelListView: NSView<PanelViewImplementationProtocol, NSTableViewDataSource, NSTableViewDelegate>

- (id) initWithFrame:(NSRect)frameRect andIC:(IconsGenerator2&)_ic;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) PanelDataSortMode sortMode;
@property (nonatomic) function<void(PanelDataSortMode)> sortModeChangeCallback;
@property (nonatomic) PanelView *panelView;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

- (const vector<PanelViewPresentationItemsColoringRule>&) coloringRules;

- (const PanelListViewGeometry&) geometry;

- (NSFont*) font;


@property (nonatomic) PanelListViewColumnsLayout columnsLayout;

@end
