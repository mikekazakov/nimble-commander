// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

@class InternalViewerController;

@interface InternalViewerWindowController : NSWindowController

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs;

- (bool) performBackgrounOpening; // call it from bg thread!

- (void)showAsFloatingWindow;
- (void)markInitialSelection:(CFRange)_selection searchTerm:(string)_request;


@property (nonatomic, readonly) InternalViewerController *internalViewerController;

@end
