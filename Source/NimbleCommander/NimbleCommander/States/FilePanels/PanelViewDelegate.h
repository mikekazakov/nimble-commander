// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <memory>

@class PanelView;
@class NCPanelContextMenu;

namespace nc::panel {
class DragReceiver;
}

@protocol PanelViewDelegate <NSObject>
@required
- (void)panelViewCursorChanged:(PanelView *)_view;

- (NCPanelContextMenu *)panelView:(PanelView *)_view requestsContextMenuForItemNo:(int)_sort_pos;

- (std::unique_ptr<nc::panel::DragReceiver>)panelView:(PanelView *)_view
                      requestsDragReceiverForDragging:(id<NSDraggingInfo>)_dragging
                                               onItem:(int)_on_sorted_index;

@end
