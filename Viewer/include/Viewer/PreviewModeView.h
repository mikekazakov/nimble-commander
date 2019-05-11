#pragma once

#include "ViewerImplementationProtocol.h"
#include "Theme.h"
#include <Cocoa/Cocoa.h>

#include <string>

@interface NCViewerPreviewModeView : NSView<NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                         path:(const std::string&)_path
                        theme:(const nc::viewer::Theme&)_theme;

@end
