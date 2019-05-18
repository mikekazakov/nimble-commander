// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>
#include <Viewer/ViewerView.h>

@class NCViewerViewController;

// make sure to destroy instances of BigFileViewSheet in main queue!
@interface NCViewerSheet : SheetController

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithFilepath:(std::string)path
                               at:(VFSHostPtr)vfs
                    viewerFactory:(const std::function<NCViewerView*(NSRect)>&)_viewer_factory
                 viewerController:(NCViewerViewController*)_viewer_controller;

- (bool) open; // call it from bg thread!
- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request;

@end
