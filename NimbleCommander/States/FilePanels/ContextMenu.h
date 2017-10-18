#pragma once

#include <VFS/VFS.h>
@class PanelController;

@interface NCPanelContextMenu : NSMenu<NSMenuDelegate>

- (instancetype) initWithItems:(vector<VFSListingItem>)_items
                       ofPanel:(PanelController*)_panel;

@end
