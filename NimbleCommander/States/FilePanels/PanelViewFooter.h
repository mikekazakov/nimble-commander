#pragma once

#include <VFS/VFS.h>

#include "PanelDataItemVolatileData.h"
#include "PanelDataStatistics.h"

@interface PanelViewFooter : NSView

- (void) updateFocusedItem:(VFSListingItem)_item VD:(nc::panel::data::ItemVolatileData)_vd; // may be empty
- (void) updateStatistics:(const nc::panel::data::Statistics&)_stats;
- (void) updateListing:(const VFSListingPtr&)_listing;

@end


