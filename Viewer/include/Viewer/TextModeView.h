#pragma once

#include "ViewerImplementationProtocol.h"
#include "BigFileViewDataBackend.h"
#include "TextModeViewDelegate.h"
#include "Theme.h"

#include <Cocoa/Cocoa.h>

@interface NCViewerTextModeView : NSView<NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(const BigFileViewDataBackend&)_backend
                        theme:(const nc::viewer::Theme&)_theme;

@property (nonatomic) id<NCViewerTextModeViewDelegate> delegate;

@end
