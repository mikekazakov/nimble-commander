#pragma once

#include "ViewerImplementationProtocol.h"
#include "DataBackend.h"
#include "HexModeViewDelegate.h"
#include "Theme.h"

#include <Cocoa/Cocoa.h>

@interface NCViewerHexModeView : NSView<NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(const nc::viewer::DataBackend&)_backend
                        theme:(const nc::viewer::Theme&)_theme;

@property (nonatomic) id<NCViewerHexModeViewDelegate> delegate;

@end

