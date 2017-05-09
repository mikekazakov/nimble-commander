#pragma once

#include "../PanelDataItemVolatileData.h"

@interface PanelListViewSizeView : NSView

- (void) buildPresentation;

// PanelListViewSizeView has no right to store listing item and hold a reference to it!
- (void) setSizeWithItem:(const VFSListingItem &)_dirent
                   andVD:(const nc::panel::data::ItemVolatileData &)_vd;

@end
