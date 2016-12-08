#pragma once

#include <VFS/VFS.h>

#include "PanelDataItemVolatileData.h"
#include "PanelDataStatistics.h"

@interface PanelViewFooter : NSView

- (void) updateFocusedItem:(VFSListingItem)_item VD:(PanelDataItemVolatileData)_vd; // may be empty
- (void) updateStatistics:(const PanelDataStatistics&)_stats;

@end


