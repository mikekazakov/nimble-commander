// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ViewerImplementationProtocol.h"
#include "DataBackend.h"
#include "TextModeViewDelegate.h"
#include "Theme.h"

#include <Cocoa/Cocoa.h>

namespace nc::viewer {
class TextModeWorkingSet;
class TextModeFrame;
}

@interface NCViewerTextModeView : NSView <NCViewerImplementationProtocol>

- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
                      backend:(std::shared_ptr<const nc::viewer::DataBackend>)_backend
                        theme:(const nc::viewer::Theme &)_theme;

@property(nonatomic) id<NCViewerTextModeViewDelegate> delegate;
@property(nonatomic, readonly) const nc::viewer::TextModeWorkingSet &workingSet;
@property(nonatomic, readonly) const nc::viewer::TextModeFrame &textFrame;

// an effective size of view's content, i.e. insets and scroller(s).
- (NSSize)contentsSize;

/**
 * Returns a number of lines which could be fitted into the view.
 * This is a floor estimation, i.e. number of fully fitting lines.
 */
- (int)numberOfLinesFittingInView;

@end
