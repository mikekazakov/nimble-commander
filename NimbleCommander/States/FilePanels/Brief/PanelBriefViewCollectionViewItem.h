#pragma once

#include <VFS/VFS.h>
#include "../PanelDataItemVolatileData.h"

@class PanelBriefView;

@interface PanelBriefViewItem : NSCollectionViewItem

/**
 * returns -1 on failure.
 */
- (int) itemIndex;

- (VFSListingItem)item;
- (void) setItem:(VFSListingItem)_item;
- (void) setVD:(PanelDataItemVolatileData)_vd;
- (void) setIcon:(NSImage*)_icon;
@property (nonatomic) bool panelActive;

- (PanelBriefView*)briefView;

- (void) setupFieldEditor:(NSScrollView*)_editor;

- (void) updateItemLayout;

@end
