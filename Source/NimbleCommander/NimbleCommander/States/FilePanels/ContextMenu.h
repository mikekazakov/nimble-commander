// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
@class PanelController;

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::utility {
class UTIDB;
}
namespace nc::panel {
class FileOpener;
}

@interface NCPanelContextMenu : NSMenu <NSMenuDelegate>

- (instancetype)initWithItems:(std::vector<VFSListingItem>)_items
                      ofPanel:(PanelController *)_panel
               withFileOpener:(nc::panel::FileOpener &)_file_opener
                    withUTIDB:(const nc::utility::UTIDB &)_uti_db
        withActivationManager:(nc::bootstrap::ActivationManager&)_activation_manager;

@end
