// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewTypes.h"
#include <optional>
#include <Cocoa/Cocoa.h>

namespace nc::panel::data {
struct SortMode;
class Model;
} // namespace nc::panel::data

@class NCPanelViewFieldEditor;

@protocol NCPanelViewPresentationProtocol <NSObject>
@required

@property(nonatomic, readonly) int itemsInColumn;
@property(nonatomic, readonly) int maxNumberOfVisibleItems;
@property(nonatomic) int cursorPosition;
@property(nonatomic) nc::panel::data::SortMode sortMode;

// ...
- (void)dataChanged;

// ...
- (void)syncVolatileData;

// ...
- (void)setData:(nc::panel::data::Model *)_data;

// ...
- (bool)isItemVisible:(int)_sorted_item_index;

// ...
- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor forItemAtIndex:(int)_sorted_item_index;

// ...
- (int)sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(nc::panel::PanelViewHitTest::Options)_options;

// ...
- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index;

@optional

// Called by the owning PanelView when the "panel.scroll_first" action is triggered
- (void)onScrollToBeginning:(NSEvent *)_event;

// Called by the owning PanelView when the "panel.scroll_last" action is triggered
- (void)onScrollToEnd:(NSEvent *)_event;

// Called by the owning PanelView when the "panel.scroll_prev_page" action is triggered
- (void)onPageUp:(NSEvent *)_event;

// Called by the owning PanelView when the "panel.scroll_next_page" action is triggered
- (void)onPageDown:(NSEvent *)_event;

@end
