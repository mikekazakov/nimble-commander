// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::core {
class VFSInstanceManager;
}

@interface VFSListWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithVFSManager:(nc::core::VFSInstanceManager &)_manager;

- (void)show;

@end
