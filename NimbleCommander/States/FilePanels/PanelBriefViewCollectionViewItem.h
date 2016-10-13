#pragma once

#include <VFS/VFS.h>
#include "../../../Files/PanelData.h"

@interface PanelBriefViewItem : NSCollectionViewItem

- (void) setItem:(VFSListingItem)_item;
- (void) setVD:(PanelData::PanelVolatileData)_vd;
- (void) setIcon:(NSImageRep*)_icon;

@end
