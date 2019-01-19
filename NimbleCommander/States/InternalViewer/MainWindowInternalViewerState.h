// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../MainWindowStateProtocol.h"
#include "../../Viewer/BigFileView.h"
#include "../../Viewer/InternalViewerToolbarProtocol.h"

@interface MainWindowInternalViewerState : NSView<NCMainWindowState>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame_rect;

- (bool)openFile:(const std::string&)_path
           atVFS:(const VFSHostPtr&)_host;

@end
