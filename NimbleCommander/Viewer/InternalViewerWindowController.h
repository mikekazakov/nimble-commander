//
//  InternalViewerWindowController.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/4/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

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
