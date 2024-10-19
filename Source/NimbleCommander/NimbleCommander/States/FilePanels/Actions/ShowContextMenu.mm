// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowContextMenu.h"
#include "../PanelView.h"
#include <Panel/PanelData.h>
#include "../PanelController.h"
#include "../ContextMenu.h"
#include <fmt/format.h>

namespace nc::panel::actions {

void ShowContextMenu::Perform(PanelController *_target, id /* _sender*/) const
{
    PanelView *const view = _target.view;

    const int curpos = view.curpos;
    if( curpos < 0 ) {
        NSBeep();
        return;
    }

    NCPanelContextMenu *const menu = [_target panelView:view requestsContextMenuForItemNo:curpos];
    if( menu == nil ) {
        NSBeep();
        return;
    }

    const int sort_pos = _target.data.SortPositionOfEntry(menu.items.front());
    const std::optional<NSRect> frame = [view frameOfItemAtSortPos:sort_pos];
    const NSSize view_size = view.frame.size;
    if( frame ) {
        // align the top of the menu's chrome with the item's frame and
        // clamp by the view's bounds
        const NSPoint p = NSMakePoint(std::clamp(frame->origin.x, 0., view_size.width),
                                      std::clamp(frame->origin.y - 5., 0., view_size.height));
        [menu popUpMenuPositioningItem:nil atLocation:p inView:view];
    }
    else {
        [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0., view_size.height) inView:view];
    }
}

} // namespace nc::panel::actions
