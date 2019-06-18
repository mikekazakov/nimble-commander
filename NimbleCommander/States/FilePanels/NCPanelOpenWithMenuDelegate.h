// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@class PanelController;

namespace nc::utility {
    class UTIDB;
}

namespace nc::panel {
    class FileOpener;
}

@interface NCPanelOpenWithMenuDelegate : NSObject<NSMenuDelegate>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFileOpener:(nc::panel::FileOpener&)_file_opener
    utiDB:(const nc::utility::UTIDB&)_uti_db;

- (void) setContextSource:(const std::vector<VFSListingItem>)_items;
- (void) addManagedMenu:(NSMenu*)_menu;

@property (weak, nonatomic) PanelController *target;

@property (class, readonly, nonatomic) NSString *regularMenuIdentifier;
@property (class, readonly, nonatomic) NSString *alwaysOpenWithMenuIdentifier;

@end
