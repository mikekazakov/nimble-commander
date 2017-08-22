#pragma once

class VFSListingItem;
@class PanelController;

@interface NCPanelContextMenu : NSMenu<NSMenuDelegate>

- (instancetype) initWithItems:(vector<VFSListingItem>)_items
                       ofPanel:(PanelController*)_panel;

@end
