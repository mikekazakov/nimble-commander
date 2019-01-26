// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../MainWindowStateProtocol.h"
#include <Viewer/BigFileView.h>
#include "../../Viewer/InternalViewerToolbarProtocol.h"

@class InternalViewerController;

@interface MainWindowInternalViewerState : NSView<NCMainWindowState>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame_rect NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame_rect
                viewerFactory:(const std::function<BigFileView*(NSRect)>&)_viewer_factory
                   controller:(InternalViewerController*)_viewer_controller;

- (bool)openFile:(const std::string&)_path
           atVFS:(const VFSHostPtr&)_host;

@end
