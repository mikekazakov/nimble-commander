// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS_fwd.h>

namespace nc::utility {
class UTIDB;
}

namespace nc::panel {
class QuickLookVFSBridge;
}

@interface NCPanelGalleryCentralView : NSView

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                        UTIDB:(const nc::utility::UTIDB &)_UTIDB
    QLHazardousExtensionsList:(const std::string &)_ql_hazard_list
                  QLVFSBridge:(nc::panel::QuickLookVFSBridge &)_ql_vfs_bridge;

- (void)showVFSItem:(VFSListingItem)_item;

@property(nonatomic) NSColor *backgroundColor;

@end
