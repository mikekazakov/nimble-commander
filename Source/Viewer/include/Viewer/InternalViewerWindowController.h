// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@class NCViewerViewController;
@class NCViewerView;
@class InternalViewerWindowController;

@protocol NCViewerWindowDelegate<NSObject>

@optional
- (void)viewerWindowWillShow:(InternalViewerWindowController*)_window;
- (void)viewerWindowWillClose:(InternalViewerWindowController*)_window;

@end

@interface InternalViewerWindowController : NSWindowController<NSWindowDelegate>

- (id) initWithFilepath:(std::string)path
                     at:(VFSHostPtr)vfs
          viewerFactory:(const std::function<NCViewerView*(NSRect)>&)_viewer_factory
             controller:(NCViewerViewController*)_controller;

- (bool) performBackgrounOpening; // call it from bg thread!

- (void)showAsFloatingWindow;
- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request;


@property (nonatomic, readonly) NCViewerViewController *internalViewerController;

@property (nonatomic, weak) id<NCViewerWindowDelegate> delegate;

@end
