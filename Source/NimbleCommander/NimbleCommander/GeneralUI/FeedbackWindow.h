// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc {
class FeedbackManager;
}

@interface FeedbackWindow : NSWindowController

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFeedbackManager:(nc::FeedbackManager &)_fm;

@property(nonatomic) int rating;

@end
