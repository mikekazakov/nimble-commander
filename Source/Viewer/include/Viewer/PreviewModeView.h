// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ViewerImplementationProtocol.h"
#include "Theme.h"
#include <Cocoa/Cocoa.h>

#include <filesystem>

@interface NCViewerPreviewModeView : NSView <NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                         path:(const std::filesystem::path &)_path
                        theme:(const nc::viewer::Theme &)_theme;

@end
