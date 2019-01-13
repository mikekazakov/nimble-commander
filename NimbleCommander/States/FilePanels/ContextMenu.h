// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
@class PanelController;

namespace nc::panel {
    class FileOpener;
}

@interface NCPanelContextMenu : NSMenu<NSMenuDelegate>

- (instancetype) initWithItems:(std::vector<VFSListingItem>)_items
                       ofPanel:(PanelController*)_panel
                withFileOpener:(nc::panel::FileOpener&)_file_opener;

@end
