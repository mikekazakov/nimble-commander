#pragma once

#include <Cocoa/Cocoa.h>

#include "HexModeFrame.h"

@interface NCViewerHexModeContentView : NSView

//- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame;
//                      backend:(const BigFileViewDataBackend&)_backend
//                        theme:(const nc::viewer::Theme&)_theme;

//@property (nonatomic) id<NCViewerTextModeViewDelegate> delegate;

@property (nonatomic) std::shared_ptr<const nc::viewer::HexModeFrame> hexFrame;
@property (nonatomic) long fileSize;

@end


