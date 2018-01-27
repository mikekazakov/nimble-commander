// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::core {
    class VFSInstanceManager;
}

@interface VFSListWindowController : NSWindowController<NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithVFSManager:(nc::core::VFSInstanceManager&)_manager;

- (void) show;

@end
