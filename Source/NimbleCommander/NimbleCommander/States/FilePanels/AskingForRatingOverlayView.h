// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc {
class FeedbackManager;
}

@interface AskingForRatingOverlayView : NSView

- (instancetype) initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (instancetype) initWithFrame:(NSRect)frameRect feedbackManager:(nc::FeedbackManager&)_fm;

@end
