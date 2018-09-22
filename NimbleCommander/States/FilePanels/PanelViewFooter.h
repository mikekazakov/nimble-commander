// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

#include "PanelDataItemVolatileData.h"
#include "PanelDataStatistics.h"

@interface NCPanelViewFooter : NSView

- (void) updateFocusedItem:(const VFSListingItem &)_item
                        VD:(nc::panel::data::ItemVolatileData)_vd; // may be empty
- (void) updateStatistics:(const nc::panel::data::Statistics&)_stats;
- (void) updateListing:(const VFSListingPtr&)_listing;

@property (nonatomic) bool active;

@end
