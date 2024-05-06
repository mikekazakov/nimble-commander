// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ViewerImplementationProtocol.h"
#include "DataBackend.h"
#include "HexModeViewDelegate.h"
#include "Theme.h"

#include <Cocoa/Cocoa.h>

@interface NCViewerHexModeView : NSView <NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(std::shared_ptr<const nc::viewer::DataBackend>)_backend
                        theme:(const nc::viewer::Theme &)_theme;

@property(nonatomic) id<NCViewerHexModeViewDelegate> delegate;

@end
