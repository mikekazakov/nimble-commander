#pragma once

#include <VFS/VFS.h>

#include "../../../Files/PanelData.h"

@interface PanelViewFooter : NSView

- (void) updateFocusedItem:(VFSListingItem)_item VD:(PanelData::PanelVolatileData)_vd; // may be empty

@end


