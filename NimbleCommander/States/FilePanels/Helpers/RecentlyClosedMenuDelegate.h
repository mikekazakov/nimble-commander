#pragma once

#include "ClosedPanelsHistory.h"
#include "../ListingPromise.h"

@class MainWindowFilePanelState;

namespace nc::panel {
    
    struct RestoreClosedTabRequest {        
        enum class Side {
            Left,
            Right
        };
        
        inline RestoreClosedTabRequest(Side _side, ListingPromise _promise):
            side(_side),
            promise(move(_promise))
        {}
        
        Side side;
        ListingPromise promise;
    };
}

@interface NCPanelsRecentlyClosedMenuDelegate : NSObject<NSMenuDelegate>

- (instancetype) initWithMenu:(NSMenu*)_menu
                      storage:(shared_ptr<nc::panel::ClosedPanelsHistory>)_storage
                panelsLocator:(function<MainWindowFilePanelState*()>)_locator;


@end
