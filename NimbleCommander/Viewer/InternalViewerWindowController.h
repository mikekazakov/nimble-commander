// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

@class InternalViewerController;
@class BigFileView;

@interface InternalViewerWindowController : NSWindowController

- (id) initWithFilepath:(std::string)path
                     at:(VFSHostPtr)vfs
          viewerFactory:(const std::function<BigFileView*(NSRect)>&)_viewer_factory
             controller:(InternalViewerController*)_controller;

- (bool) performBackgrounOpening; // call it from bg thread!

- (void)showAsFloatingWindow;
- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request;


@property (nonatomic, readonly) InternalViewerController *internalViewerController;

@end
