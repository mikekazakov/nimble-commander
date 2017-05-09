#pragma once

#include "../PanelViewImplementationProtocol.h"

namespace nc::panel::data {
    class Model;
}

struct PanelViewPresentationItemsColoringRule;
@class PanelView;
class PanelListViewGeometry;
class IconsGenerator2;
struct PanelListViewColumnsLayout;

@interface PanelListView: NSView<PanelViewImplementationProtocol, NSTableViewDataSource, NSTableViewDelegate>

- (id) initWithFrame:(NSRect)frameRect andIC:(IconsGenerator2&)_ic;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) nc::panel::data::SortMode sortMode;
@property (nonatomic) function<void(nc::panel::data::SortMode)> sortModeChangeCallback;
@property (nonatomic) PanelView *panelView;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(nc::panel::data::Model*)_data;

- (const PanelListViewGeometry&) geometry;

- (NSFont*) font;

- (NSMenu*) columnsSelectionMenu;

@property (nonatomic) PanelListViewColumnsLayout columnsLayout;

@end

void DrawTableVerticalSeparatorForView(NSView *v);
