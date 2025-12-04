// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

// Used by PanelView to handle Left/Right keypresses.
@property(nonatomic, readonly) int itemsInColumn;

// Used by PanelView to handle PageUp/PageDown keypresses.
@property(nonatomic, readonly) int maxNumberOfVisibleItems;

@property(nonatomic) int cursorPosition;

// Called by the owning PanelView whenever the contents of the associated Data is changed.
// e.g. after reloading or go to a different directory.
- (void)onDataChanged;

// Called by the owning PanelView whenever the volatile contents of the associated Data is changed.
// e.g. after a directory size was calculated, highlighting was changed, icon was assigned etc.
- (void)onVolatileDataChanged;

// Called once by the owning PanelView upon initialization to provide access to the underlying data of the panel.
- (void)setData:(nc::panel::data::Model *)_data;

// Returns true if the item specified by the sorted index is currently visible.
// Any partial visibility counts.
- (bool)isItemVisible:(int)_sorted_item_index;

// ...
- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor forItemAtIndex:(int)_sorted_item_index;

// ...
- (int)sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(nc::panel::PanelViewHitTest::Options)_options;

// ...
- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index;

@optional

// Called by the owning PanelView when the existing Panel Data has its sorting mode changed.
// This notification will not be set when the data is replaced entirely, the presentation implementation should
// rely on "setData:" for that.
- (void)onDataSortingHasChanged;

// Called by the owning PanelView when the "panel.scroll_first" action is triggered
- (void)onScrollToBeginning:(NSEvent *)_event;

// Called by the owning PanelView when the "panel.scroll_last" action is triggered
- (void)onScrollToEnd:(NSEvent *)_event;

// Called by the owning PanelView when the "panel.scroll_prev_page" action is triggered
- (void)onPageUp:(NSEvent *)_event;

// Called by the owning PanelView when the "panel.scroll_next_page" action is triggered
- (void)onPageDown:(NSEvent *)_event;

@end
