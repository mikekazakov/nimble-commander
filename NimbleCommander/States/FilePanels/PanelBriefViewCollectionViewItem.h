#pragma once

#include <VFS/VFS.h>
#include "../../../Files/PanelData.h"

@interface PanelBriefViewItem : NSCollectionViewItem

//@property (strong) NSView *view;

- (void) setItem:(VFSListingItem)_item;
- (void) setVD:(PanelData::PanelVolatileData)_vd;

@end
