// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Quartz/Quartz.h>
#include "../PanelPreview.h"

namespace nc::panel {
    class QuickLookVFSBridge;
}

@interface NCPanelQLPanelAdaptor : NSObject<NCPanelPreview,
                                            QLPreviewPanelDataSource,
                                            QLPreviewPanelDelegate>

- (instancetype) initWithBridge:(nc::panel::QuickLookVFSBridge&)_vfs_bridge;

- (bool)registerExistingQLPreviewPanelFor:(id)_controller;
- (bool)unregisterExistingQLPreviewPanelFor:(id)_controller;

@property (readonly, nonatomic, weak) id owner;
@property (readonly, nonatomic) nc::panel::QuickLookVFSBridge &bridge;

@end
