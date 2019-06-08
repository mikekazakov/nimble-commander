// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ViewerImplementationProtocol.h"
#include "DataBackend.h"
#include "TextModeViewDelegate.h"
#include "Theme.h"

#include <Cocoa/Cocoa.h>

@interface NCViewerTextModeView : NSView<NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(const nc::viewer::DataBackend&)_backend
                        theme:(const nc::viewer::Theme&)_theme;

@property (nonatomic) id<NCViewerTextModeViewDelegate> delegate;

@end
