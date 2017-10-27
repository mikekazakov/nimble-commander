// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
@class PanelController;

@interface NCPanelContextMenu : NSMenu<NSMenuDelegate>

- (instancetype) initWithItems:(vector<VFSListingItem>)_items
                       ofPanel:(PanelController*)_panel;

@end
