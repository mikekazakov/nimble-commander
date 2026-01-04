// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include "ClosedPanelsHistory.h"
#include "../ListingPromise.h"

@class MainWindowFilePanelState;

namespace nc::panel {

struct RestoreClosedTabRequest {
    enum class Side : uint8_t {
        Left,
        Right
    };

    RestoreClosedTabRequest(Side _side, ListingPromise _promise) : side(_side), promise(std::move(_promise)) {}

    Side side;
    ListingPromise promise;
};
} // namespace nc::panel

@interface NCPanelsRecentlyClosedMenuDelegate : NSObject <NSMenuDelegate, NSMenuItemValidation>

- (instancetype)initWithMenu:(NSMenu *)_menu
                     storage:(std::shared_ptr<nc::panel::ClosedPanelsHistory>)_storage
               panelsLocator:(std::function<MainWindowFilePanelState *()>)_locator;

@end
