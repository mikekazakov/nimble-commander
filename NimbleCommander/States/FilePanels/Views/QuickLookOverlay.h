// Copyright (C) 2013-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelPreview.h"
#include <Config/Config.h>
#include <Cocoa/Cocoa.h>

namespace nc::panel {
class QuickLookVFSBridge;
}

@interface NCPanelQLOverlay : NSView <NCPanelPreview>

- (instancetype)initWithFrame:(NSRect)frameRect
                       bridge:(nc::panel::QuickLookVFSBridge &)_vfs_bridge
                       config:(nc::config::Config &)_config;

@end
