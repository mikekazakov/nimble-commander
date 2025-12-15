// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS_fwd.h>

namespace nc::utility {
class UTIDB;
}

@interface NCPanelGalleryCentralView : NSView

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                        UTIDB:(const nc::utility::UTIDB &)_UTIDB
    QLHazardousExtensionsList:(const std::string &)_ql_hazard_list;

- (void)showVFSItem:(VFSListingItem)_item;

@end
